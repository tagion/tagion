module tagion.gossip.GossipNet;

import tagion.gossip.InterfaceNet;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event : EventMonitorCallbacks;
import tagion.hashgraph.ConsensusExceptions;
import tagion.Base : consensusCheck, Pubkey, Buffer;
import tagion.crypto.aes.AESCrypto;
@safe
class StdRequestNet : RequestNet {

    Buffer calcHash(const(ubyte[]) data) const {
        import std.digest.sha : SHA256;
        import std.digest.digest;
        return digest!SHA256(data).idup;
    }

    //TO-DO: Implement a general request func. if makes sense.
    abstract void request(HashGraph hashgraph, immutable(ubyte[]) fingerprint);

    // override void sendToScriptingEngine(immutable(Buffer) eventbody) {
    //     assert(0, "Not implement for this test");
    // }


//    abstract void sendToScriptingEngine(immutable(Buffer) eventbody);

}

@safe
class StdSecureNet : StdRequestNet, SecureNet {
    // The Eva value is set up a low negative number
    // to check the two-complement round wrapping if the altitude.
    enum AES_KEY_LENGTH=128;

    import tagion.crypto.secp256k1.NativeSecp256k1;
    import std.digest.hmac;

    //    private immutable(ubyte)[] _privkey;
    private Pubkey _pubkey;
    private immutable(ubyte[]) delegate(immutable(ubyte[]) message) @safe _sign;

    Pubkey pubkey() pure const nothrow {
        return _pubkey;
    }

    Buffer hashPubkey() const {
        return calcHash(cast(Buffer)_pubkey);
    }


    bool verify(T)(T pack, immutable(ubyte)[] signature, Pubkey pubkey) if ( __traits(compiles, pack.serialize) ) {
        auto message=calcHash(pack.serialize);
        return verify(message, signature, pubkey);
    }

    private NativeSecp256k1 _crypt;
    bool verify(immutable(ubyte[]) message, immutable(ubyte)[] signature, Pubkey pubkey) {

        if ( signature.length == 0 && signature.length <= 520) {
            consensusCheck!SecurityConsensusException(0, ConsensusFailCode.SECURITY_SIGNATURE_SIZE_FAULT);
        }
        return _crypt.verify(message, signature, cast(Buffer)pubkey);
    }

    immutable(ubyte[]) sign(T)(T pack) if ( __traits(compiles, pack.serialize) ) {
        auto message=calcHash(pack.serialize);
        auto result=sign(message);
        return result;
    }

    immutable(ubyte[]) sign(immutable(ubyte[]) message)
    in {
        assert(_sign !is null, format("Signature function has not been intialized. Use the %s function", basename!generatePrivKey));
        assert(message.length == 32);
    }
    do {
        return _sign(message);
    }

    void generateKeyPair(string passphrase)
        in {
            assert(_sign is null);
        }
    do {
        import std.digest.sha : SHA256;
        import std.string : representation;
        alias AES=AESCrypto!256;

        auto hmac = HMAC!SHA256(passphrase.representation);
        auto data=hmac.finish.dup;

        // Generate Key pair
        do {
            data=hmac.put(data).finish.dup;
        } while (!_crypt.secKeyVerify(data));

        _pubkey=_crypt.computePubkey(data);
        // Generate scramble key for the private key
        import std.random;

        void scramble(ref ubyte[] data, ubyte[] xor=null) @safe {
            import std.random;
            // enum from =ubyte.min;
            // enum to   =ubyte.max;
            auto gen1 = Mt19937(unpredictableSeed); //Random(unpredictableSeed);
            foreach(ref s; data) {
                s=gen1.front & ubyte.max; //cast(ubyte)uniform!("[]")(from, to, gen1);
            }
            foreach(i, ref s; xor) {
                s^=data[i];
            }
        }
        auto seed=new ubyte[32];

        scramble(seed);
        // CBR: Note AES need to be change to beable to handle const keys
        auto aes_key=calcHash(seed).dup;

        scramble(seed);

        // Encrypt private key
        auto encrypted_privkey=new ubyte[data.length];
        AES.encrypt(aes_key, data, encrypted_privkey);

        AES.encrypt(calcHash(seed), encrypted_privkey, data);
        scramble(seed);

        AES.encrypt(aes_key, encrypted_privkey, data);

        AES.encrypt(aes_key, data, seed);

        AES.encrypt(aes_key, encrypted_privkey, data);

        immutable(ubyte[]) local_sign(immutable(ubyte[]) message) @safe {
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
            immutable(ubyte[]) result() @trusted {
                return _crypt.sign(message, privkey);
            }
            return result();
        }

        _sign=&local_sign;
    }

    this(NativeSecp256k1 crypt) {
        this._crypt = crypt;
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

    import tagion.hashgraph.Event : Event;
    // alias Tides=int[immutable(Pubkey)];
    abstract Event receive(immutable(ubyte[]) data, Event delegate(immutable(ubyte)[] leading_event_fingerprint) @safe register_leading_event );
//    abstract void send(Pubkey channel, immutable(ubyte[]) data);

    import tagion.crypto.secp256k1.NativeSecp256k1 : NativeSecp256k1;
    this(NativeSecp256k1 crypt) {
        super(crypt);
    }
}
