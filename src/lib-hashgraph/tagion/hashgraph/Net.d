module tagion.hashgraph.Net;

import tagion.hashgraph.GossipNet;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event : EventMonitorCallbacks;
import tagion.hashgraph.ConsensusExceptions;
import tagion.Base : consensusCheck, Pubkey, Buffer;

@safe
class StdRequestNet : RequestNet {

    Buffer calcHash(const(ubyte[]) data) const {
        import std.digest.sha : SHA256;
        import std.digest.digest;
        return digest!SHA256(data).idup;
    }

    //TO-DO: Implement a general request func. if makes sense.
    abstract void request(HashGraph hashgraph, immutable(ubyte[]) fingerprint);

    //TO-DO: Implement
    // Buffer eventHashFromId(immutable uint id) {
    //     assert(0, "Not implement for this test");
    // }

}

@safe
class StdSecureNet : StdRequestNet, SecureNet {
    // The Eva value is set up a low negative number
    // to check the two-complement round wrapping if the altitude.
    enum int eva_altitude=-77;

    import tagion.crypto.secp256k1.NativeSecp256k1;
    import std.digest.hmac;

    //    private immutable(ubyte)[] _privkey;
    private Pubkey _pubkey;
    private immutable(ubyte[]) delegate(immutable(ubyte[]) message) @safe _sign;

    Pubkey pubkey() pure const nothrow {
        return _pubkey;
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
    out (signature) {
        assert(verify(message, signature, pubkey));
    }
    do {
        return _sign(message);
    }

    @trusted
    private struct AESCrypto {
        import tango.util.cipher.AES;
        static private AES _aes;
        static this() {
            _aes=new AES;
        }
        static private void cipher_stream(const(ubyte[]) indata, ubyte[] outdata)
            in {
                assert(indata);
                assert(indata.length == outdata.length);
                assert(indata.length % _aes.blockSize == 0);
            }
        do {
            for(size_t i=0; i<indata.length; i+=_aes.blockSize) {
                immutable last=i+_aes.blockSize;
                _aes.update(indata[i..last], outdata[i..last]);
            }
        }
        static void encrypt(const(ubyte[]) key, const(ubyte[]) indata, ubyte[] outdata)
            in {
                assert(indata);
                assert(indata.length == outdata.length);
            }
        do {
            _aes.init(true, key.dup);
            cipher_stream(indata, outdata);
        }
        static void decrypt(const(ubyte[]) key, const(ubyte[]) indata, ubyte[] outdata)
            in {
                assert(indata);
                assert(indata.length == outdata.length);
            }
        do {
            _aes.init(false, key.dup);
            cipher_stream(indata, outdata);
        }
    }

    void generateKeyPair(string passphrase)
        in {
            assert(_sign is null);
        }
    do {
        import std.digest.sha : SHA256;
        import std.string : representation;


        auto hmac = HMAC!SHA256(passphrase.representation);
        auto data=hmac.finish;

        // Generate Key pair
        do {
            data=hmac.put(data).finish;
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
        AESCrypto.encrypt(aes_key, data, encrypted_privkey);

        AESCrypto.encrypt(calcHash(seed), encrypted_privkey, data);
        scramble(seed);

        AESCrypto.encrypt(aes_key, encrypted_privkey, data);

        AESCrypto.encrypt(aes_key, data, seed);

        AESCrypto.encrypt(aes_key, encrypted_privkey, data);

        immutable(ubyte[]) local_sign(immutable(ubyte[]) message) @safe {
            // CBR:
            // Yes I know it is security by obscurity
            // But just don't want to have the private in clear text in memory
            // for long period of time
            auto privkey=new ubyte[encrypted_privkey.length];
            scope(exit) {
                auto seed=new ubyte[32];
                scramble(seed, aes_key);
                AESCrypto.encrypt(aes_key, privkey, encrypted_privkey);
                AESCrypto.encrypt(calcHash(seed), encrypted_privkey, privkey);
            }
            AESCrypto.decrypt(aes_key, encrypted_privkey, privkey);
            immutable(ubyte[]) result() @trusted {
                return _crypt.sign(message, privkey);
            }
            return result();
        }

        _sign=&local_sign;
        debug {
            import tagion.crypto.Hash : hex=toHexString;
            //TO-DO: Impl. tracing service or red. std.stout stream.
            //fout.writefln("pubkey(%s) =%s",passphrase, _pubkey[0..7].hex);
        }

    }

    this(NativeSecp256k1 crypt) {
        this._crypt = crypt;
    }
}

@safe
abstract class StdGossipNet : StdSecureNet, GossipNet {
    static private shared uint _next_global_id;
    static private shared uint[immutable(Pubkey)] _node_id_pair;

    static uint globalNodeId(immutable(Pubkey) channel) {
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
    alias Tides=int[immutable(Pubkey)];
    abstract Event receive(immutable(ubyte[]) data, Event delegate(immutable(ubyte)[] leading_event_fingerprint) @safe register_leading_event );
//    abstract void send(Pubkey channel, immutable(ubyte[]) data);

    import tagion.crypto.secp256k1.NativeSecp256k1 : NativeSecp256k1;
    this(NativeSecp256k1 crypt) {
        super(crypt);
    }
}

@safe
interface NetCallbacks : EventMonitorCallbacks {
    void wavefront_state_receive(const(HashGraph.Node) n);
    //void wavefront_state_send(const(HashGraph.Node) n);
    void sent_tidewave(immutable(Pubkey) receiving_channel, const(StdGossipNet.Tides) tides);
    void received_tidewave(immutable(Pubkey) sending_channel, const(StdGossipNet.Tides) tides);
    void receive(immutable(ubyte[]) data);
    void send(immutable(Pubkey) channel, immutable(ubyte[]) data);
    void consensus_failure(const(ConsensusException) e);
    void exiting(const(HashGraph.Node) n);
}
