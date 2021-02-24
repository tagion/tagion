module tagion.gossip.InterfaceNet;

//import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Event;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.hibon.Document : Document;
//import tagion.utils.Queue;
import tagion.basic.ConsensusExceptions;
import tagion.basic.Basic;

import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;

alias check = consensusCheck!(GossipConsensusException);
alias consensus = consensusCheckArguments!(GossipConsensusException);


//import tagion.hashgraph.HashGraphBasic : Tides;

@safe
interface NetCallbacks : EventMonitorCallbacks {

//    void sent_tidewave(immutable(Pubkey) receiving_channel, const(Tides) tides);

    void receive(const(Document) doc);
    void send(const Pubkey channel, const(Document) data);


    void consensus_failure(const(ConsensusException) e);
}

@safe
interface GossipNet : SecureNet {
//    Event receive(const(Document) received, Event delegate(Buffer father_fingerprint) @safe register_leading_event );
//    void receive(const(Document) received); //, Event delegate(Buffer father_fingerprint) @safe register_leading_event );

//    void send(const Pubkey channel, const(Document) doc);
    void send(const Pubkey channel, const(HiPRC.Sender) sender);
    // final void send(T)(const Pubkey channel, const T message) if(isHiBONRecord!T) {
    //     send(message.toDoc);
    // }

//     immutable(Pubkey) selectRandomNode(const bool active=true);


// //    send(pkey, sender.toDoc.serialize);
// //    void set(immutable(Pubkey)[] pkeys);

//     NetCallbacks callbacks();

// //    HashGraphI hashgraph() pure nothrow;

// //    void hashgraph(HashGraphI h) nothrow;

// //    void send(immutable(Pubkey) channel, ref immutable(ubyte[]) data);
// //    alias Request=bool delegate(Buffer);
//     // This function is call by the HashGraph.whatIsNotKnowBy
//     // and is use to collect node to be send to anotehr node
// //    uint globalNodeId(immutable(Pubkey) channel);

//     @property
//     const(ulong) time() pure const;

//     @property
//     void time(const(ulong) t);

    // Tides tideWave(HiBON hibon, bool build_tides);

    ///void wavefront(Pubkey received_pubkey, Document doc, ref Tides tides);

//    void register_wavefront();

}

// @safe
// interface FactoryNet {
//     HashNet hashnet() const;

//     //  SecureNet securenet(immutable(Buffer) derive);
// }

@safe
interface ScriptNet : GossipNet {
    import std.concurrency;
    @property void transcript_tid(Tid tid);

    @property Tid transcript_tid() pure nothrow;

    @property void scripting_engine_tid(Tid tid);

    @property Tid scripting_engine_tid();
}
