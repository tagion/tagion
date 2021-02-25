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
import tagion.communication.HiRPC;

alias check = consensusCheck!(GossipConsensusException);
alias consensus = consensusCheckArguments!(GossipConsensusException);


//import tagion.hashgraph.HashGraphBasic : Tides;

@safe
interface NetCallbacks : EventMonitorCallbacks {

//    void sent_tidewave(immutable(Pubkey) receiving_channel, const(Tides) tides);

    void receive(const(Document) doc);
    void send(const Pubkey channel, const(HiRPC.Sender) sender);


    void consensus_failure(const(ConsensusException) e);
}

@safe
interface GossipNet {
    void send(const Pubkey channel, const(HiRPC.Sender) sender);
}

@safe
interface ScriptNet {
    import std.concurrency;
    @property void transcript_tid(Tid tid);

    @property Tid transcript_tid() pure nothrow;

    @property void scripting_engine_tid(Tid tid);

    @property Tid scripting_engine_tid();
}
