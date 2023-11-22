module tagion.crypto.SecureNet;

import std.range;
import std.typecons : TypedefType;
import std.traits;
import tagion.basic.ConsensusExceptions;
import tagion.basic.Types : Buffer;
import tagion.basic.Version : ver;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types : Fingerprint, Signature;
import tagion.crypto.aes.AESCrypto;
import tagion.crypto.random.random;
import tagion.hibon.Document : Document;

package alias check = Check!SecurityConsensusException;

@safe
class StdHashNet : HashNet {
    import std.format;

    enum HASH_SIZE = 32;
    @nogc final uint hashSize() const pure nothrow scope {
        return HASH_SIZE;
    }

    immutable(Buffer) rawCalcHash(scope const(ubyte[]) data) const scope {
        import std.digest;
        import std.digest.sha : SHA256;

        return digest!SHA256(data).idup;
    }

    Fingerprint calcHash(scope const(ubyte[]) data) const {
        return Fingerprint(rawCalcHash(data));
    }

    final immutable(Buffer) HMAC(scope const(ubyte[]) data) const pure {
        import std.digest.hmac : digestHMAC = HMAC;
        import std.digest.sha : SHA256;

        auto hmac = digestHMAC!SHA256(data);
        return hmac.finish.idup;
    }

    Fingerprint calcHash(const(Document) doc) const {
        return Fingerprint(rawCalcHash(doc.serialize));
    }

    enum hashname = "sha256";
    string multihash() const pure nothrow @nogc {
        return hashname;
    }
}

@safe
class StdSecureNet : StdHashNet, SecureNet {
    import tagion.crypto.secp256k1.NativeSecp256k1; 
    import std.format;
    import std.string : representation;
    import tagion.basic.ConsensusExceptions;
    import tagion.crypto.Types : Pubkey;
    import tagion.crypto.aes.AESCrypto;

    private Pubkey _pubkey;
    /**
       This function
       returns
       If method is SIGN the signed message or
       If method is DERIVE it returns the derived privat key
    */
    @safe
    interface SecretMethods {
        immutable(ubyte[]) sign(const(ubyte[]) message) const;
        void tweak(const(ubyte[]) tweek_code, out ubyte[] tweak_privkey) const;
        immutable(ubyte[]) ECDHSecret(scope const(Pubkey) pubkey) const;
        void clone(StdSecureNet net) const;
    }

    protected SecretMethods _secret;

    @nogc final Pubkey pubkey() pure const nothrow {
        return _pubkey;
    }

    final Buffer hmacPubkey() const {
        return HMAC(cast(Buffer) _pubkey);
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

    const NativeSecp256k1 crypt;

    bool verify(const Fingerprint message, const Signature signature, const Pubkey pubkey) const {
        consensusCheck!(SecurityConsensusException)(
                signature.length == NativeSecp256k1.SIGNATURE_SIZE,
                ConsensusFailCode.SECURITY_SIGNATURE_SIZE_FAULT);
        return crypt.verify(cast(Buffer) message, cast(Buffer) signature, cast(Buffer) pubkey);
    }

    Signature sign(const Fingerprint message) const
    in(_secret !is null,
                format("Signature function has not been intialized. Use the %s function", basename!generatePrivKey))
        in(_secret !is null, 
format("Signature function has not been intialized. Use the %s function", fullyQualifiedName!generateKeyPair))
    do {
        return Signature(_secret.sign(cast(Buffer) message));
    }

    final void derive(string tweak_word, ref ubyte[] tweak_privkey) {
        const data = HMAC(tweak_word.representation);
        derive(data, tweak_privkey);
    }

    final void derive(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey)
    in(tweak_privkey.length == NativeSecp256k1.TWEAK_SIZE)
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
        auto result = new StdSecureNet;
        result.createKeyPair(tweak_privkey);
        return result;
    }

    final void createKeyPair(ref ubyte[] seckey)
    in (seckey.length == SECKEY_SIZE)
    do {
        scope (exit) {
            getRandom(seckey);
        }

        ubyte[] privkey;
        scope (exit) {
            privkey[] = 0;
        }
        crypt.createKeyPair(seckey, privkey);
        alias AES = AESCrypto!256;
        _pubkey = crypt.getPubkey(privkey);
        auto aes_key_iv = new ubyte[AES.KEY_SIZE + AES.BLOCK_SIZE];
        getRandom(aes_key_iv);
        auto aes_key = aes_key_iv[0 .. AES.KEY_SIZE];
        auto aes_iv = aes_key_iv[AES.KEY_SIZE .. $];
        // Encrypt private key
        auto encrypted_privkey = new ubyte[privkey.length];
        AES.encrypt(aes_key, aes_iv, privkey, encrypted_privkey);
        @safe
        void do_secret_stuff(scope void delegate(const(ubyte[]) privkey) @safe dg) {
            // CBR:
            // Yes I know it is security by obscurity
            // But just don't want to have the private in clear text in memory
            // for long period of time
            auto tmp_privkey = new ubyte[encrypted_privkey.length];
            scope (exit) {
                getRandom(aes_key_iv);
                AES.encrypt(aes_key, aes_iv, tmp_privkey, encrypted_privkey);
                AES.encrypt(rawCalcHash(encrypted_privkey ~ aes_key_iv), aes_iv, encrypted_privkey, tmp_privkey);
            }
            AES.decrypt(aes_key, aes_iv, encrypted_privkey, tmp_privkey);
            dg(tmp_privkey);
        }

        @safe class LocalSecret : SecretMethods {
            immutable(ubyte[]) sign(const(ubyte[]) message) const {
                immutable(ubyte)[] result;
                ubyte[crypt.MESSAGE_SIZE] _aux_random;
                ubyte[] aux_random = _aux_random;
                getRandom(aux_random);
                do_secret_stuff((const(ubyte[]) privkey) { result = crypt.sign(message, privkey, aux_random); });
                return result;
            }

            void tweak(const(ubyte[]) tweak_code, out ubyte[] tweak_privkey) const {
                do_secret_stuff((const(ubyte[]) privkey) @safe { crypt.privTweak(privkey, tweak_code, tweak_privkey); });
            }

            immutable(ubyte[]) ECDHSecret(scope const(Pubkey) pubkey) const {
                Buffer result;
                do_secret_stuff((const(ubyte[]) privkey) @safe {
                    ubyte[] seckey;
                    scope (exit) {
                        seckey[] = 0;
                    }
                    crypt.getSecretKey(privkey, seckey);
                    result = crypt.createECDHSecret(seckey, cast(Buffer) pubkey);
                });
                return result;
            }

            void clone(StdSecureNet net) const {
                do_secret_stuff((const(ubyte[]) privkey) @safe {
                    auto _privkey = privkey.dup;
                    net.createKeyPair(_privkey); // Not createKeyPair scrambles the privkey
                });
            }
        }

        _secret = new LocalSecret;
    }

    /**
    Params:
    passphrase = Passphrase is compatible with bip39
    salt = In bip39 the salt should be "mnemonic"~word 
*/
    void generateKeyPair(
            scope const(char[]) passphrase,
    scope const(char[]) salt = null,
    void delegate(scope const(ubyte[]) data) @safe dg = null)
    in
        (_secret is null)
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
    scope const(Pubkey) pubkey) const {
        return crypt.createECDHSecret(seckey, cast(Buffer) pubkey);
    }

    immutable(ubyte[]) ECDHSecret(scope const(Pubkey) pubkey) const {
        return _secret.ECDHSecret(pubkey);
    }

    Pubkey getPubkey(scope const(ubyte[]) seckey) const {
        return Pubkey(crypt.getPubkey(seckey));
    }

    this() nothrow {
        crypt = new NativeSecp256k1;
    }

    this(shared(StdSecureNet) other_net) @trusted {
        this();
        synchronized (other_net) {
            auto unshared_secure_net = cast(StdSecureNet) other_net;
            unshared_secure_net._secret.clone(this);
        }
    }

    SecureNet clone() const {
        StdSecureNet result = new StdSecureNet;
        this._secret.clone(result);
        return result;
    }

    unittest {
        auto other_net = new StdSecureNet;
        other_net.generateKeyPair("Secret password to be copied");
        auto shared_net = (() @trusted => cast(shared) other_net)();
        SecureNet copy_net = new StdSecureNet(shared_net);
        assert(other_net.pubkey == copy_net.pubkey);

    }

    void eraseKey() pure nothrow {
        _secret = null;
    }

    unittest { // StdSecureNet rawSign
        const some_data = "some message";
        SecureNet net = new StdSecureNet;
        net.generateKeyPair("Secret password");
        SecureNet bad_net = new StdSecureNet;
        bad_net.generateKeyPair("Wrong Secret password");

        const message = net.calcHash(some_data.representation);

        Signature signature = net.sign(message);

        assert(!net.verify(message, signature, bad_net.pubkey));
        assert(net.verify(message, signature, net.pubkey));

    }

    unittest { // StdSecureNet document
        import std.exception : assertThrown;
        import tagion.basic.ConsensusExceptions : SecurityConsensusException;
        import tagion.hibon.HiBON;
        import tagion.hibon.HiBONJSON;

        SecureNet net = new StdSecureNet;
        net.generateKeyPair("Secret password");

        Document doc;
        {
            auto h = new HiBON;
            h["message"] = "Some message";
            doc = Document(h);
        }

        const doc_signed = net.sign(doc);

        assert(net.rawCalcHash(doc.serialize) == net.calcHash(doc.serialize), "should produce same hash");

        assert(doc_signed.message == net.rawCalcHash(doc.serialize));
        assert(net.verify(doc, doc_signed.signature, net.pubkey));

        SecureNet bad_net = new StdSecureNet;
        bad_net.generateKeyPair("Wrong Secret password");
        assert(!net.verify(doc, doc_signed.signature, bad_net.pubkey));
    }

    unittest {
        SecureNet net = new StdSecureNet;
        net.generateKeyPair("Secret password");

        foreach (i; 0 .. 10) {
            SimpleRecord data;
            data.x = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX20%s".format(i);

            auto fingerprint = net.calcHash(data);
            auto second_fingerprint = net.calcHash(data.toDoc.serialize);
            assert(fingerprint == second_fingerprint);

            auto sig = net.sign(data).signature;
            assert(net.verify(fingerprint, sig, net.pubkey));
        }

    }

    unittest { /// clone
        SecureNet net = new StdSecureNet;
        net.generateKeyPair("Very secret word");
        auto net_clone = net.clone;
        assert(net_clone.pubkey == net.pubkey);
        SimpleRecord doc;
        doc.x = "Hugo";
        const sig = net.sign(doc).signature;
        const clone_sig = net_clone.sign(doc).signature;
        const net_check = new StdSecureNet;
        const msg = net.calcHash(doc);
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
        super();
        generateKeyPair(passphrase);
    }

    override Signature sign(const Fingerprint message) const {
        const false_message = super.calcHash(message ~ message);
        return super.sign(false_message);
    }
}
