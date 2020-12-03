module tagion.gossip.InterfaceNet;

import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.utils.Queue;
import tagion.basic.ConsensusExceptions;
import tagion.basic.Basic;

enum ExchangeState : uint {
    NONE,
        INIT_TIDE,
        TIDAL_WAVE,
        FIRST_WAVE,
        SECOND_WAVE,
        BREAKING_WAVE
        }

@safe
struct Package {
    private const(HiBON) block;
    private Pubkey pubkey;
    immutable ExchangeState type;
    immutable(ubyte[]) signature;

    this(GossipNet net, const(HiBON) block, ExchangeState type) {
        this.block=block;
        this.type=type;
        this.pubkey=net.pubkey;
//        import tagion.services.LoggerService;
        @trusted
        immutable(ubyte[]) sig_calc(){
            import std.stdio;
            import tagion.hibon.HiBONJSON;
            try {
                immutable data=block.serialize;
                immutable message=net.calcHash(data);
                auto signed = net.sign(message);
                return signed;
            }
            catch(Exception e){
                pragma(msg, "fixme():Why this this print here should it be removed");
                writeln("EXCEPTION::%s", e.msg);
            }
            catch(Throwable e){
                pragma(msg, "fixme():Why a print here if there is throw after (is this some tempoary debug info)");
                writeln("THROWABLE::%s", e.msg);
                throw e;
            }
            return null;
        }
        signature = sig_calc();
    }

    HiBON toHiBON() inout {
        auto hibon=new HiBON;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            alias typeof(m) mtype;
            static if ( __traits(compiles, m.toHiBON) ) {
                hibon[name]=m.toHiBON;
            }
            else {
                static if ( is(mtype == enum) ) {
                    hibon[name]=cast(uint)m;
                }
                else static if ( isBufferType!mtype ) {
                    hibon[name]=cast(Buffer)m;
                }
                else {
                    hibon[name]=m;
                }
            }
        }
        return hibon;
    }

    immutable(ubyte[]) serialize() const {
        return toHiBON.serialize;
    }
}


@safe
interface NetCallbacks : EventMonitorCallbacks {
    void wavefront_state_receive(const(HashGraph.Node) n);
    void sent_tidewave(immutable(Pubkey) receiving_channel, const(PackageNet.Tides) tides);
    void received_tidewave(immutable(Pubkey) sending_channel, const(PackageNet.Tides) tides);
    void receive(Buffer data);
    void send(immutable(Pubkey) channel, immutable(ubyte[]) data);


    void consensus_failure(const(ConsensusException) e);
    void exiting(const(HashGraph.Node) n);
}


@safe
interface HashNet {
    uint hashSize() const pure nothrow;
    immutable(Buffer) calcHash(scope const(ubyte[]) data) const;
    immutable(Buffer) HMAC(scope const(ubyte[]) data) const;
    /++
     Hash used for Merkle tree
     +/
    immutable(Buffer) hashOf(scope const(ubyte[]) h1, scope const(ubyte[]) h2) const;

    immutable(Buffer) hashOf(const(Document) doc) const;
}


@safe
interface RequestNet : HashNet {
    /++
     + Request a missing event from the network
     +/
    void request(HashGraph h, immutable(Buffer) event_hash);
}

@safe
interface SecureNet : HashNet {
    Pubkey pubkey() pure const nothrow;
    bool verify(immutable(ubyte[]) message, immutable(ubyte[]) signature, Pubkey pubkey) const;
    bool verify(T)(T pack, immutable(ubyte)[] signature, Pubkey pubkey) const if ( __traits(compiles, pack.serialize) );

    // The private should be added implicite by the GossipNet
    // The message is a hash of the 'real' message
    immutable(ubyte[]) sign(immutable(ubyte[]) message) const;
    immutable(ubyte[]) sign(T)(T pack) const if ( __traits(compiles, pack.serialize) );
    void createKeyPair(ref ubyte[] privkey);
    void generateKeyPair(string passphrase);
    void drive(string tweak_word, shared(SecureNet) secure_net);
    void drive(const(ubyte[]) tweak_code, shared(SecureNet) secure_net);
    void drive(string tweak_word, ref ubyte[] tweak_privkey);
    void drive(const(ubyte[]) tweak_code, ref ubyte[] tweak_privkey);
    Pubkey drivePubkey(const(ubyte[]) tweak_code);
    Pubkey drivePubkey(string tweak_word);

    Buffer mask(const(ubyte[]) _mask) const;

}

@safe
interface PackageNet {
    enum int eva_altitude=-77;
    alias Tides=int[immutable(Pubkey)];
    alias ReceiveQueue = Queue!(immutable(ubyte[]));

//    Payload evaPackage();
    const(Package) buildEvent(const(HiBON) block, ExchangeState type);

    Tides tideWave(HiBON hibon, bool build_tides);

    @property
    ReceiveQueue queue();
}

@safe
interface GossipNet : SecureNet, RequestNet, PackageNet {
    Event receive(const(Buffer) received, Event delegate(immutable(ubyte)[] father_fingerprint) @safe register_leading_event );
    void send(immutable(Pubkey) channel, immutable(ubyte[]) data);

    immutable(Pubkey) selectRandomNode(const bool active=true);
    void set(immutable(Pubkey)[] pkeys);

    NetCallbacks callbacks();

//    void send(immutable(Pubkey) channel, ref immutable(ubyte[]) data);
    alias Request=bool delegate(immutable(ubyte[]));
    // This function is call by the HashGraph.whatIsNotKnowBy
    // and is use to collect node to be send to anotehr node
    uint globalNodeId(immutable(Pubkey) channel);

    @property
    const(ulong) time() pure const;
    @property
    void time(const(ulong) t);

    // @property
    // string node_name() pure const;

    // @property
    // void node_name(string name);
}

@safe
interface FactoryNet {
    HashNet hashnet() const;

    //  SecureNet securenet(immutable(Buffer) drive);
}

// @safe
// interface DocumentNet : GossipNet, DocumentHashNet {
// }

@safe
interface ScriptNet : GossipNet {
    import std.concurrency;
    @property void transcript_tid(Tid tid);
    @property Tid transcript_tid() pure nothrow;

    @property void scripting_engine_tid(Tid tid);

    @property Tid scripting_engine_tid();
}
