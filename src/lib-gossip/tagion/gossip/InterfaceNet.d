module tagion.gossip.InterfaceNet;

import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.utils.HiBON : HiBON;
import tagion.utils.Document : Document;
import tagion.utils.Queue;
import tagion.hashgraph.ConsensusExceptions;
import tagion.Base;

enum ExchangeState : uint {
    NONE,
        INIT_TIDE,
        TIDE_WAVE,
        FIRST_WAVE,
        SECOND_WAVE,
        BREAK_WAVE
        }

@safe
struct Package {
    private const(HiBON) block;
    private Pubkey pubkey;
    immutable ExchangeState type;
    immutable(ubyte[]) signature;

    this(GossipNet net, const(HiBON) block,  ExchangeState type) {
        this.block=block;
        this.type=type;
        this.pubkey=net.pubkey;
        immutable data=block.serialize;
        immutable message=net.calcHash(data);
        signature=net.sign(message);
    }

    HiBON toHiBON() inout {
        auto bson=new HiBON;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            alias typeof(m) mtype;
            static if ( __traits(compiles, m.toHiBON) ) {
                bson[name]=m.toHiBON;
            }
            else {
                static if ( is(mtype == enum) ) {
                    bson[name]=cast(uint)m;
                }
                else static if ( isBufferType!mtype ) {
                    bson[name]=cast(Buffer)m;
                }
                else {
                    bson[name]=m;
                }
            }
            //}
        }
        return bson;
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
interface RequestNet {
    immutable(Buffer) calcHash(immutable(ubyte[]) data) inout;
    /++
     + Request a missing event from the network
     +/
    void request(HashGraph h, immutable(Buffer) event_hash);
}

@safe
interface SecureNet : RequestNet {
    Pubkey pubkey() pure const nothrow;
    bool verify(immutable(ubyte[]) message, immutable(ubyte[]) signature, Pubkey pubkey);

    // The private should be added implicite by the GossipNet
    // The message is a hash of the 'real' message
    immutable(ubyte[]) sign(immutable(ubyte[]) message);
    void generateKeyPair(string passphrase);
}

@safe
interface PackageNet {
    enum int eva_altitude=-77;
    alias Tides=int[immutable(Pubkey)];
    alias ReceiveQueue = Queue!(immutable(ubyte[]));
    // const(HRPC.HRPCSender) bulidEvent(HBSON block, ExchangeState type=ExchangeState.NONE);
    Payload evaPackage();
    const(Package) buildEvent(const(HiBON) block, ExchangeState type);

    Tides tideWave(HiBON bson, bool build_tides);

    @property
    ReceiveQueue queue();
}

@safe
interface GossipNet : SecureNet, PackageNet {
    Event receive(const(Buffer) received, Event delegate(immutable(ubyte)[] father_fingerprint) @safe register_leading_event );
    void send(immutable(Pubkey) channel, immutable(ubyte[]) data);
//    void send(immutable(Pubkey) channel, ref const(Package) pack);

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
interface ScriptNet : GossipNet {
    import std.concurrency;
    @property void transcript_tid(Tid tid);
    @property Tid transcript_tid() pure nothrow;

    @property void scripting_engine_tid(Tid tid);

    @property Tid scripting_engine_tid();
}
