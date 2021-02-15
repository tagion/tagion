module tagion.gossip.InterfaceNet;

import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Event;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.hibon.Document : Document;
//import tagion.utils.Queue;
import tagion.basic.ConsensusExceptions;
import tagion.basic.Basic;

import tagion.crypto.SecureInterface : HashNet, SecureNet;

alias check = consensusCheck!(GossipConsensusException);
alias consensus = consensusCheckArguments!(GossipConsensusException);


@safe
struct Package {
    private const(HiBON) block;
    private Pubkey pubkey;
    immutable ExchangeState type;
    immutable(Signature) signature;

    this(GossipNet net, const(HiBON) block, const ExchangeState type) {
        this.block=block;
        this.type=type;
        this.pubkey=net.pubkey;
//        import tagion.services.LoggerService;
        @trusted
        Signature sig_calc(){
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
            return Signature(null);
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

    // immutable(ubyte[]) serialize() const {
    //     return toHiBON.serialize;
    // }
}


import tagion.hashgraph.HashGraphBasic : Tides;

@safe
interface NetCallbacks : EventMonitorCallbacks {

    void sent_tidewave(immutable(Pubkey) receiving_channel, const(Tides) tides);

    void receive(const(Document) doc);
    void send(immutable(Pubkey) channel, const(Document) data);


    void consensus_failure(const(ConsensusException) e);
}



version(none)
@safe
interface RequestNet : HashNet {
    /++
     + Request a missing event from the network
     +/
    void request(scope immutable(Buffer) fingerprint);

    Event lookup(scope immutable(Buffer) fingerprint);

    void eliminate(scope immutable(Buffer) fingerprint);

    void register(scope immutable(Buffer) fingerprint, Event event);

    bool isRegistered(scope immutable(Buffer) fingerprint) pure;

    size_t number_of_registered_event() const pure nothrow;
}


@safe
interface PackageNet {
//    alias ReceiveQueue = Queue!(const(Document));

//    Payload evaPackage();
    //   const(Document) buildPackage(const(HiBON) pack, const ExchangeState type);

    // @property
    // ReceiveQueue queue();
}

@safe
interface GossipNet : SecureNet, PackageNet {
//    Event receive(const(Document) received, Event delegate(Buffer father_fingerprint) @safe register_leading_event );
    void receive(const(Document) received); //, Event delegate(Buffer father_fingerprint) @safe register_leading_event );

    void send(immutable(Pubkey) channel, const(Document) doc);

    immutable(Pubkey) selectRandomNode(const bool active=true);

    void set(immutable(Pubkey)[] pkeys);

    NetCallbacks callbacks();

//    void send(immutable(Pubkey) channel, ref immutable(ubyte[]) data);
//    alias Request=bool delegate(Buffer);
    // This function is call by the HashGraph.whatIsNotKnowBy
    // and is use to collect node to be send to anotehr node
    uint globalNodeId(immutable(Pubkey) channel);

    @property
    const(ulong) time() pure const;

    @property
    void time(const(ulong) t);

    // Tides tideWave(HiBON hibon, bool build_tides);

    ///void wavefront(Pubkey received_pubkey, Document doc, ref Tides tides);

//    void register_wavefront();

}

@safe
interface FactoryNet {
    HashNet hashnet() const;

    //  SecureNet securenet(immutable(Buffer) derive);
}

@safe
interface ScriptNet : GossipNet {
    import std.concurrency;
    @property void transcript_tid(Tid tid);

    @property Tid transcript_tid() pure nothrow;

    @property void scripting_engine_tid(Tid tid);

    @property Tid scripting_engine_tid();
}
