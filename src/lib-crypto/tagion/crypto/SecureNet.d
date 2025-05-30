/// Secure object for doing cryptographic operations
module tagion.crypto.SecureNet;

import std.range;
import std.typecons : TypedefType;
import std.traits;
import tagion.errors.ConsensusExceptions;
import tagion.basic.Types : Buffer;
import tagion.basic.Version : ver;
public import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types : Fingerprint, Signature;
import tagion.crypto.aes.AESCrypto;
import tagion.crypto.random.random;
import tagion.hibon.Document : Document;

@safe:
package alias check = Check!SecurityConsensusException;

///
const hash_net = new StdHashNet;

class StdHashNet : HashNet {
    import std.format;

    enum HASH_SIZE = 32;
    @nogc final uint hashSize() const pure nothrow scope {
        return HASH_SIZE;
    }

    immutable(Buffer) rawCalcHash(scope const(ubyte[]) data) const pure scope {
        import std.digest;
        import std.digest.sha : SHA256;

        return digest!SHA256(data).idup;
    }

    Fingerprint calc(scope const(ubyte[]) data) const pure {
        return Fingerprint(rawCalcHash(data));
    }

    final immutable(Buffer) HMAC(scope const(ubyte[]) data) const pure {
        import std.digest.hmac : digestHMAC = HMAC;
        import std.digest.sha : SHA256;

        auto hmac = digestHMAC!SHA256(data);
        return hmac.finish.idup;
    }

    Fingerprint calc(const(Document) doc) const pure {
        return Fingerprint(rawCalcHash(doc.serialize));
    }

    enum hashname = "sha256";
    string multihash() const pure nothrow @nogc {
        return hashname;
    }
}

enum SignatureSchema {
    STANDARD
}

SecureNet createSecureNet(const SignatureSchema s = SignatureSchema.STANDARD) nothrow {
    with (SignatureSchema) {
        final switch (s) {
        case STANDARD:
            const h = new StdHashNet;
            return new StdSecureNet(h);
        }
    }
    assert(0);
}

class StdSecureNet : StdHashNet, SecureNet {
    import tagion.crypto.secp256k1.NativeSecp256k1;
    import std.format;
    import std.string : representation;
    import tagion.errors.ConsensusExceptions;
    import tagion.crypto.Types : Pubkey;
    import tagion.crypto.aes.AESCrypto;

    const HashNet _hash;
    private Pubkey _pubkey;
    /**
       This function
       returns
       If method is SIGN the signed message or
       If method is DERIVE it returns the derived privat key
    */
    @safe
    interface SecretMethods {
        const pure {
            immutable(ubyte[]) sign(const(ubyte[]) message);
            void tweak(const(ubyte[]) tweak_code, out ubyte[] tweak_privkey);
            immutable(ubyte[]) ECDHSecret(scope const(Pubkey) pubkey);
            void clone(StdSecureNet net);
            void __expose(out scope ubyte[] _privkey);
        }
    }

    protected SecretMethods _secret;

    const(HashNet) hash() pure const nothrow scope {
        return _hash;
    }

    @nogc final Pubkey pubkey() pure const nothrow {
        return _pubkey;
    }

    final Pubkey derivePubkey(string tweak_word) const {
        const tweak_code = HMAC(tweak_word.representation);
        return derivePubkey(tweak_code);
    }

    final Pubkey derivePubkey(const(ubyte[]) tweak_code) const {
        Pubkey result;
        const pkey = cast(const(ubyte[])) _pubkey;
        result = crypt.pubTweak(pkey, tweak_code);
        return result;
    }

    SecureNet.Signed sign(const Document doc) const pure {
        const fingerprint = hash.calc(doc);
        return SecureNet.Signed(sign(fingerprint), fingerprint);
    }

    const NativeSecp256k1 crypt;

    bool verify(const Fingerprint message, const Signature signature, const Pubkey pubkey) const pure {
        consensusCheck!(SecurityConsensusException)(
                signature.length == NativeSecp256k1.SIGNATURE_SIZE,
                ConsensusFailCode.SECURITY_SIGNATURE_SIZE_FAULT);
        return crypt.verify(cast(const(Buffer)) message, cast(const(Buffer)) signature, cast(const(Buffer)) pubkey);
    }

    Signature sign(const Fingerprint message) const pure
    in (_secret !is null,
        format("Signature function has not been initialized. Use the %s function", basename!generatePrivKey))
    in (_secret !is null,
        format("Signature function has not been initialized. Use the %s function", fullyQualifiedName!generateKeyPair))
    do {
        return Signature(_secret.sign(cast(const(Buffer)) message));
    }

    final void derive(string tweak_word, ref ubyte[] tweak_privkey) {
        const data = HMAC(tweak_word.representation);
        derive(data, tweak_privkey);
    }

    final void derive(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey)
    in (tweak_privkey.length == NativeSecp256k1.TWEAK_SIZE)
    do {
        _secret.tweak(tweak_code, tweak_privkey);
    }

    void derive(string tweak_word, shared(SecureNet) secure_net) {
        const tweak_code = HMAC(tweak_word.representation);
        derive(tweak_code, secure_net);

    }

    @trusted
    void derive(const(ubyte[]) tweak_code, shared(SecureNet) secure_net)
    in (_secret !is null)
    do {
        synchronized (secure_net) {
            ubyte[] tweak_privkey = tweak_code.dup;
            auto unshared_secure_net = cast(SecureNet) secure_net;
            unshared_secure_net.derive(tweak_code, tweak_privkey);
            createKeyPair(tweak_privkey);
        }
    }

    const(SecureNet) derive(const(ubyte[]) tweak_code) const {
        ubyte[] tweak_privkey;
        _secret.tweak(tweak_code, tweak_privkey);
        auto result = new StdSecureNet(_hash);
        result.createKeyPair(tweak_privkey);
        return result;
    }

    final void createKeyPair(ref ubyte[] seckey) pure
    in (seckey.length == SECKEY_SIZE)
    do {
        scope (exit) {
            getRandom(seckey);
        }

        ubyte[] keypair;
        scope (exit) {
            keypair[] = 0;
        }
        crypt.createKeyPair(seckey, keypair);
        alias AES = AESCrypto!256;
        _pubkey = crypt.getPubkey(keypair);
        auto aes_key_iv = new ubyte[AES.KEY_SIZE + AES.BLOCK_SIZE];
        getRandom(aes_key_iv);
        auto aes_key = aes_key_iv[0 .. AES.KEY_SIZE];
        auto aes_iv = aes_key_iv[AES.KEY_SIZE .. $];
        // Encrypt private key
        auto encrypted_keypair = new ubyte[keypair.length];
        AES.encrypt(aes_key, aes_iv, keypair, encrypted_keypair);
        @safe
        void do_secret_stuff(scope void delegate(const(ubyte[]) keypair) pure @safe dg) pure {
            // CBR:
            // Yes I know it is security by obscurity
            // But just don't want to have the private in clear text in memory
            // for long period of time
            auto tmp_keypair = new ubyte[encrypted_keypair.length];
            scope (exit) {
                getRandom(aes_key_iv);
                AES.encrypt(aes_key, aes_iv, tmp_keypair, encrypted_keypair);
                AES.encrypt(rawCalcHash(encrypted_keypair ~ aes_key_iv), aes_iv, encrypted_keypair, tmp_keypair);
            }
            AES.decrypt(aes_key, aes_iv, encrypted_keypair, tmp_keypair);
            dg(tmp_keypair);
        }

        @safe class LocalSecret : SecretMethods {
            immutable(ubyte[]) sign(const(ubyte[]) message) const pure {
                immutable(ubyte)[] result;
                ubyte[crypt.MESSAGE_SIZE] _aux_random;
                ubyte[] aux_random = _aux_random;
                getRandom(aux_random);
                do_secret_stuff((const(ubyte[]) keypair) { result = crypt.sign(message, keypair, aux_random); });
                return result;
            }

            void tweak(const(ubyte[]) tweak_code, out ubyte[] tweak_keypair) const {
                do_secret_stuff((const(ubyte[]) keypair) @safe { crypt.privTweak(keypair, tweak_code, tweak_keypair); });
            }

            immutable(ubyte[]) ECDHSecret(scope const(Pubkey) pubkey) const pure {
                Buffer result;
                do_secret_stuff((const(ubyte[]) keypair) @safe {
                    ubyte[] seckey;
                    scope (exit) {
                        seckey[] = 0;
                    }
                    crypt.getSecretKey(keypair, seckey);
                    scope const pkey = cast(const(Buffer)) pubkey;
                    result = crypt.createECDHSecret(seckey, pkey);
                });
                return result;
            }

            void clone(StdSecureNet net) const pure {
                do_secret_stuff((const(ubyte[]) keypair) @safe { auto _keypair = keypair.dup; net.createKeyPair(_keypair); });
            }

            void __expose(out scope ubyte[] _keypair) const pure {
                do_secret_stuff((const(ubyte[]) keypair) @safe { _keypair = keypair.dup; });
            }
        }

        _secret = new LocalSecret;
    }

    void __expose(out scope ubyte[] privkey) const {
        _secret.__expose(privkey);
    }

    /**
    Params:
    passphrase = Passphrase is compatible with bip39
    salt = In bip39 the salt should be "mnemonic"~word 
*/
    void generateKeyPair(
            scope const(char[]) passphrase,
            scope const(char[]) salt = null,
            void delegate(scope const(ubyte[]) data) pure @safe dg = null)
    in (_secret is null)
    do {
        import tagion.crypto.pbkdf2;
        import std.digest.sha : SHA512;

        enum count = 2048;
        enum dk_length = 64;

        alias pbkdf2_sha512 = pbkdf2!SHA512;
        auto data = pbkdf2_sha512(passphrase.representation, salt.representation, count, dk_length);
        scope (exit) {
            data[] = 0;
        }
        auto _priv_key = data[0 .. 32];

        if (dg !is null) {
            dg(_priv_key);
        }
        createKeyPair(_priv_key);
    }

    immutable(ubyte[]) ECDHSecret(
            scope const(ubyte[]) seckey,
            scope const(Pubkey) pubkey)
    const {
        scope const pkey = cast(const(Buffer)) pubkey;
        return crypt.createECDHSecret(seckey, pkey);
    }

    immutable(ubyte[]) ECDHSecret(scope const(Pubkey) pubkey) const {
        return _secret.ECDHSecret(pubkey);
    }

    Pubkey getPubkey(scope const(ubyte[]) seckey) const pure {
        return Pubkey(crypt.getPubkey(seckey));
    }

    this(const HashNet hash) nothrow {
        _hash = hash;
        crypt = new NativeSecp256k1;
    }

    this(shared(StdSecureNet) other_net) @trusted {
        synchronized (other_net) {
            this(cast(const)(other_net._hash));
            auto unshared_secure_net = cast(StdSecureNet) other_net;
            unshared_secure_net._secret.clone(this);
        }
    }

    SecureNet clone() const {
        StdSecureNet result = new StdSecureNet(_hash);
        this._secret.clone(result);
        return result;
    }

    SecureNet clone() const shared @trusted {
        synchronized (this) {
            const _tmp = cast(const) this;
            return _tmp.clone;
        }
    }

    unittest {
        auto other_net = createSecureNet;
        other_net.generateKeyPair("Secret password to be copied");
        auto shared_net = (() @trusted => cast(shared) other_net)();
        SecureNet copy_net = shared_net.clone;
        assert(other_net.pubkey == copy_net.pubkey);

    }

    void eraseKey() pure nothrow {
        _secret = null;
    }

    unittest { // StdSecureNet rawSign
        const some_data = "some message";
        SecureNet net = createSecureNet;
        net.generateKeyPair("Secret password");
        SecureNet bad_net = createSecureNet;
        bad_net.generateKeyPair("Wrong Secret password");

        const message = net.hash.calc(some_data.representation);

        Signature signature = net.sign(message);

        assert(!net.verify(message, signature, bad_net.pubkey));
        assert(net.verify(message, signature, net.pubkey));

    }

    unittest { // StdSecureNet document
        import std.exception : assertThrown;
        import tagion.errors.ConsensusExceptions : SecurityConsensusException;
        import tagion.hibon.HiBON;
        import tagion.hibon.HiBONJSON;

        SecureNet net = createSecureNet;
        net.generateKeyPair("Secret password");

        Document doc;
        {
            auto h = new HiBON;
            h["message"] = "Some message";
            doc = Document(h);
        }

        const doc_signed = net.sign(doc);

        assert(net.hash.rawCalcHash(doc.serialize) == net.hash.calc(doc.serialize), "should produce same hash");

        assert(doc_signed.message == net.hash.rawCalcHash(doc.serialize));
        assert(net.verify(doc, doc_signed.signature, net.pubkey));

        SecureNet bad_net = createSecureNet;
        bad_net.generateKeyPair("Wrong Secret password");
        assert(!net.verify(doc, doc_signed.signature, bad_net.pubkey));
    }

    unittest {
        SecureNet net = createSecureNet;
        net.generateKeyPair("Secret password");

        foreach (i; 0 .. 10) {
            SimpleRecord data;
            data.x = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX20%s".format(i);

            auto fingerprint = net.hash.calc(data);
            auto second_fingerprint = net.hash.calc(data.toDoc.serialize);
            assert(fingerprint == second_fingerprint);

            auto sig = net.sign(data).signature;
            assert(net.verify(fingerprint, sig, net.pubkey));
        }

    }

    unittest { /// clone
        SecureNet net = createSecureNet;
        net.generateKeyPair("Very secret word");
        auto net_clone = net.clone;
        assert(net_clone.pubkey == net.pubkey);
        SimpleRecord doc;
        doc.x = "Hugo";
        const sig = net.sign(doc).signature;
        const clone_sig = net_clone.sign(doc).signature;
        const net_check = createSecureNet;
        const msg = net.hash.calc(doc);
        assert(net_check.verify(msg, sig, net.pubkey));
        assert(net_check.verify(msg, clone_sig, net_clone.pubkey));
    }
}

version (unittest) {
    import std.format;
    import tagion.hibon.HiBONRecord;

    static struct SimpleRecord {
        string x;

        mixin HiBONRecord;
    }
}

@safe
class BadSecureNet : StdSecureNet {
    this(string passphrase) {
        const h = new StdHashNet;
        super(h);
        generateKeyPair(passphrase);
    }

    override Signature sign(const Fingerprint message) const {
        const false_message = super.calc(message ~ message);
        return super.sign(false_message);
    }
}
