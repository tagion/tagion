module tagion.gossip.InterfaceNet;

import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.utils.Queue;
import tagion.hashgraph.ConsensusExceptions;
import tagion.Base;

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

    this(GossipNet net, const(HiBON) block,  ExchangeState type) {
        this.block=block;
        this.type=type;
        this.pubkey=net.pubkey;
        immutable data=block.serialize;
        immutable message=net.calcHash(data);
        signature=net.sign(message);
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
            //}
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
    immutable(Buffer) calcHash(immutable(ubyte[]) data) inout;
}

@safe
interface RequestNet : HashNet {
    /++
     + Request a missing event from the network
     +/
    void request(HashGraph h, immutable(Buffer) event_hash);
}

@safe
interface SecureDriveNet : HashNet {
    Net drive(Net : SecureNet)(string tweak_name);
}

@safe
interface SecureNet : HashNet {
    Pubkey pubkey() pure const nothrow;
    bool verify(immutable(ubyte[]) message, immutable(ubyte[]) signature, Pubkey pubkey) const;

    // The private should be added implicite by the GossipNet
    // The message is a hash of the 'real' message
    immutable(ubyte[]) sign(immutable(ubyte[]) message) const;
    void generateKeyPair(string passphrase);
    //   SecureNet drive(string name);
}

@safe
interface PackageNet {
    enum int eva_altitude=-77;
    alias Tides=int[immutable(Pubkey)];
    alias ReceiveQueue = Queue!(immutable(ubyte[]));

    Payload evaPackage();
    const(Package) buildEvent(const(HiBON) block, ExchangeState type);

    Tides tideWave(HiBON hibon, bool build_tides);

    @property
    ReceiveQueue queue();
}

@safe
interface GossipNet : SecureNet, RequestNet, SecureDriveNet, PackageNet {
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
interface FactoryNet {
    HashNet hashnet() const;

    //  SecureNet securenet(immutable(Buffer) drive);
}

@safe
interface ScriptNet : GossipNet {
    import std.concurrency;
    @property void transcript_tid(Tid tid);
    @property Tid transcript_tid() pure nothrow;

    @property void scripting_engine_tid(Tid tid);

    @property Tid scripting_engine_tid();
}
