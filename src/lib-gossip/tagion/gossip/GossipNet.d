module tagion.gossip.GossipNet;

import std.concurrency;
import std.stdio : File;
import std.format;
import std.exception : assumeUnique;
import std.string : representation;
import core.time : MonoTime;

import tagion.Options;
import tagion.basic.Basic : EnumText, Pubkey, Buffer, buf_idup, basename;
import tagion.basic.ConsensusExceptions : convertEnum;
//, consensusCheck, consensusCheckArguments;
import tagion.utils.Miscellaneous: cutHex;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord : HiBONPrefix;


import tagion.utils.LRU;
import tagion.utils.Queue;

import tagion.gossip.InterfaceNet;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.basic.ConsensusExceptions;
import tagion.hashgraph.HashGraphBasic;

import tagion.crypto.aes.AESCrypto;
//import tagion.crypto.secp256k1.NativeSecp256k1;

import tagion.basic.Logger;

void scramble(scope ref ubyte[] data, scope ubyte[] xor=null) @safe {
    import std.random;
    auto gen = Mt19937(unpredictableSeed);
    foreach(ref s; data) { //, gen1, StoppingPolicy.shortest)) {
        s=gen.front & ubyte.max;
        gen.popFront;
    }
    foreach(i, x; xor) {
        data[i]^=x;
    }
}

@safe
class StdHashNet : HashNet {
    protected enum HASH_SIZE=32;
    final uint hashSize() const pure nothrow {
        return HASH_SIZE;
    }

    final immutable(Buffer) calcHash(scope const(ubyte[]) data) const {
        import std.digest.sha : SHA256;
        import std.digest;
        return digest!SHA256(data).idup;
    }

    @trusted
    final immutable(Buffer) HMAC(scope const(ubyte[]) data) const {
        import std.exception : assumeUnique;
        import std.digest.sha : SHA256;
        import std.digest.hmac : digestHMAC=HMAC;
        scope hmac = digestHMAC!SHA256(data);
        auto result = hmac.finish.dup;
        pragma(msg, typeof(result));
        return assumeUnique(result);
    }

    immutable(Buffer) hashOf(scope const(ubyte[]) h1, scope const(ubyte[]) h2) const {
        return calcHash(h1~h2);
    }

    immutable(Buffer) hashOf(const(Document) doc) const {
        auto range=doc[];
        if (!range.empty && (range.front.key[0] is HiBONPrefix.HASH)) {
            pragma(msg, "FIXME(cbr): not working with integers");
            immutable value_data=range.front.data[range.front.dataPos..range.front.dataPos + range.front.dataSize];
            return calcHash(value_data);
        }
        return calcHash(doc.serialize);
    }
}

@safe
class StdSecureNet : StdHashNet, SecureNet  {
//    immutable(Buffer) calcHash(scope const(ubyte[]) data) const;

    import tagion.crypto.secp256k1.NativeSecp256k1;
    import tagion.basic.Basic : Pubkey;
    import tagion.crypto.aes.AESCrypto;
    import tagion.gossip.GossipNet : scramble;
    import tagion.basic.ConsensusExceptions;

    import std.format;
    import std.string : representation;


    private Pubkey _pubkey;
    /**
       This function
       returns
       If method is SIGN the signed message or
       If method is DRIVE it returns the drived privat key
     */
    @safe
    interface SecretMethods {
        immutable(ubyte[]) sign(immutable(ubyte[]) message) const;
        void tweakMul(const(ubyte[]) tweek_code, ref ubyte[] tweak_privkey);
        void tweakAdd(const(ubyte[]) tweek_code, ref ubyte[] tweak_privkey);
        Buffer mask(const(ubyte[]) _mask) const;
    }

    protected SecretMethods _secret;

    final Pubkey pubkey() pure const nothrow {
        return _pubkey;
    }

    final Buffer hmacPubkey() const {
        return HMAC(cast(Buffer)_pubkey);
    }

    final Pubkey drivePubkey(string tweak_word) const {
        const tweak_code=HMAC(tweak_word.representation);
        return drivePubkey(tweak_code);
    }

    final Pubkey drivePubkey(const(ubyte[]) tweak_code) const {
        Pubkey result;
        const pkey=cast(const(ubyte[]))_pubkey;
        result=_crypt.pubKeyTweakMul(pkey, tweak_code);
        return result;
    }

    final bool verify(T)(T pack, immutable(ubyte)[] signature, Pubkey pubkey) const if ( __traits(compiles, pack.serialize) ) {
        auto message=calcHash(pack.serialize);
        return verify(message, signature, pubkey);
    }

    protected NativeSecp256k1 _crypt;
    final bool verify(immutable(ubyte[]) message, immutable(ubyte)[] signature, Pubkey pubkey) const {
        consensusCheck!(SecurityConsensusException)(signature.length != 0 && signature.length <= 520,
            ConsensusFailCode.SECURITY_SIGNATURE_SIZE_FAULT);
        return _crypt.verify(message, signature, cast(Buffer)pubkey);
    }

    final immutable(ubyte[]) sign(T)(T pack) const if ( __traits(compiles, pack.serialize) ) {
        auto message=calcHash(pack.serialize);
        auto result=sign(message);
        return result;
    }

    final immutable(ubyte[]) sign(immutable(ubyte[]) message) const
    in {
        assert(_secret !is null, format("Signature function has not been intialized. Use the %s function", basename!generatePrivKey));
        assert(message.length == 32);
    }
    do {
        import std.traits;
        assert(_secret !is null, format("Signature function has not been intialized. Use the %s function", fullyQualifiedName!generateKeyPair));

        return _secret.sign(message);
    }

    void drive(string tweak_word, ref ubyte[] tweak_privkey) {
        const data = HMAC(tweak_word.representation);
        drive(data, tweak_privkey);
    }

    void drive(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey)
        in {
            assert(tweak_privkey.length >= 32);
        }
    do {
        _secret.tweakMul(tweak_code, tweak_privkey);
    }

    final Buffer mask(const(ubyte[]) _mask) const {
        return _secret.mask(_mask);
    }

    @trusted
    void drive(string tweak_word, shared(SecureNet) secure_net) {
        const tweak_code=HMAC(tweak_word.representation);
        drive(tweak_code, secure_net);
    }

    @trusted
    void drive(const(ubyte[]) tweak_code, shared(SecureNet) secure_net)
        in {
            assert(_secret);
        }
    do {
        synchronized(secure_net) {
            ubyte[] tweak_privkey = tweak_code.dup;
            auto unshared_secure_net = cast(SecureNet)secure_net;
            unshared_secure_net.drive(tweak_code, tweak_privkey);
            createKeyPair(tweak_privkey);
        }
    }

    final void createKeyPair(ref ubyte[] privkey)
        in {
            assert(_crypt.secKeyVerify(privkey));
            assert(_secret is null);
        }
    do {
        import std.digest.sha : SHA256;
        import std.string : representation;
        alias AES=AESCrypto!256;
        _pubkey = _crypt.computePubkey(privkey);
        // Generate scramble key for the private key
        import std.random;

        auto seed=new ubyte[32];

        scramble(seed);
        // CBR: Note AES need to be change to beable to handle const keys
        auto aes_key=calcHash(seed).dup;

        scramble(seed);

        // Encrypt private key
        auto encrypted_privkey=new ubyte[privkey.length];
        AES.encrypt(aes_key, privkey, encrypted_privkey);

        AES.encrypt(calcHash(seed), encrypted_privkey, privkey);
        scramble(seed);

        AES.encrypt(aes_key, encrypted_privkey, privkey);

        AES.encrypt(aes_key, privkey, seed);

        AES.encrypt(aes_key, encrypted_privkey, privkey);

        @safe
        void do_secret_stuff(scope void delegate(const(ubyte[]) privkey) @safe dg) {
            // CBR:
            // Yes I know it is security by obscurity
            // But just don't want to have the private in clear text in memory
            // for long period of time
            auto privkey=new ubyte[encrypted_privkey.length];
            scope(exit) {
                auto seed=new ubyte[32];
                scramble(seed, aes_key);
                AES.encrypt(aes_key, privkey, encrypted_privkey);
                AES.encrypt(calcHash(seed), encrypted_privkey, privkey);
            }
            AES.decrypt(aes_key, encrypted_privkey, privkey);
            dg(privkey);
        }

        @safe class LocalSecret : SecretMethods {
            immutable(ubyte[]) sign(immutable(ubyte[]) message) const {
                immutable(ubyte)[] result;
                do_secret_stuff((const(ubyte[]) privkey) {
                        result = _crypt.sign(message, privkey);
                    });
                return result;
            }
            void tweakMul(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey) {
                do_secret_stuff((const(ubyte[]) privkey) @safe {
                        // scope hmac = HMAC!SHA256(tweek_code.representation);
                        // auto data = hmac.finish.dup;
                        _crypt.privKeyTweakMul(privkey, tweak_code, tweak_privkey);
                    });
            }
            void tweakAdd(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey) {
                do_secret_stuff((const(ubyte[]) privkey) @safe {
                        // scope hmac = HMAC!SHA256(tweek_code.representation);
                        // auto data = hmac.finish.dup;
                        _crypt.privKeyTweakAdd(privkey, tweak_code, tweak_privkey);
                    });
            }
            Buffer mask(const(ubyte[]) _mask) const {
                import std.algorithm.iteration : sum;
                check(sum(_mask) != 0, ConsensusFailCode.SECURITY_MASK_VECTOR_IS_ZERO);
                Buffer result;
                do_secret_stuff((const(ubyte[]) privkey) @safe {
                        import tagion.utils.Miscellaneous : xor;
                        auto data = xor(privkey, _mask);
                        result=calcHash(calcHash(data));
                    });
                return result;
            }
        }
        _secret = new LocalSecret;
    }

    final void generateKeyPair(string passphrase)
        in {
            assert(_secret is null);
        }
    do {
        import std.digest.sha : SHA256;
        import std.digest.hmac : digestHMAC=HMAC;
        import std.string : representation;
        alias AES=AESCrypto!256;

        scope hmac = digestHMAC!SHA256(passphrase.representation);
        auto data = hmac.finish.dup;

        // Generate Key pair
        do {
            data = hmac.put(data).finish.dup;
        } while (!_crypt.secKeyVerify(data));

        createKeyPair(data);
    }

    this() {
        this._crypt = new NativeSecp256k1;
    }
}

@safe
abstract class StdGossipNet : StdSecureNet, GossipNet {
    static private shared uint _next_global_id;
    static private shared uint[immutable(Pubkey)] _node_id_pair;

    uint globalNodeId(immutable(Pubkey) channel) {
        if ( channel in _node_id_pair ) {
            return _node_id_pair[channel];
        }
        else {
            return setGlobalNodeId(channel);
        }
    }

    @trusted
    static private uint setGlobalNodeId(immutable(Pubkey) channel) {
        import core.atomic;
        auto result = _next_global_id;
        _node_id_pair[channel] = _next_global_id;
        atomicOp!"+="(_next_global_id, 1);
        return result;
    }

    this( HashGraph hashgraph) {
        _hashgraph=hashgraph;
        super();
    }

    override NetCallbacks callbacks() {
        return (cast(NetCallbacks)Event.callbacks);
    }

    static struct Init {
        uint timeout;
        uint node_id;
        uint N;
        string monitor_ip_address;
        ushort monitor_port;
        uint seed;
        string node_name;
    }

    bool online() const  {
        // Does my own node exist and do the node have an event
        auto own_node=_hashgraph.getNode(pubkey);
        return (own_node !is null) && (own_node.event !is null);
    }

    protected {
        ulong _current_time;
        HashGraph _hashgraph;
    }

    override void receive(const(Document) doc) {
        _hashgraph.wavefront_machine(doc);
    }


    @property
    void time(const(ulong) t) {
        _current_time=t;
    }

    @property
    const(ulong) time() pure const {
        return _current_time;
    }

    protected Tid _transcript_tid;
    @property void transcript_tid(Tid tid)
        @trusted in {
        assert(_transcript_tid != _transcript_tid.init, format("%s hash already been set", __FUNCTION__));
    }
    do {
        _transcript_tid=tid;
    }

    @property Tid transcript_tid() pure nothrow {
        return _transcript_tid;
    }

    protected Tid _scripting_engine_tid;
    @property void scripting_engine_tid(Tid tid) @trusted in {
        assert(_scripting_engine_tid != _scripting_engine_tid.init, format("%s hash already been set", __FUNCTION__));
    }
    do {
        _scripting_engine_tid=tid;
    }

    @property Tid scripting_engine_tid() pure nothrow {
        return _scripting_engine_tid;
    }
}
