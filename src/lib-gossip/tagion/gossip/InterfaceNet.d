module tagion.gossip.InterfaceNet;

import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Event;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.hibon.Document : Document;

//import tagion.utils.Queue;
import tagion.basic.ConsensusExceptions;
import tagion.basic.Types : Pubkey;
import tagion.communication.HiRPC;
import tagion.utils.StdTime;

import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
import tagion.communication.HiRPC;

alias check = consensusCheck!(GossipConsensusException);
alias consensus = consensusCheckArguments!(GossipConsensusException);

//import tagion.hashgraph.HashGraphBasic : Tides;
version (none) @safe
interface NetCallbacks : EventMonitorCallbacks
{

    //    void sent_tidewave(immutable(Pubkey) receiving_channel, const(Tides) tides);

    void receive(const(Document) doc);
    void send(const Pubkey channel, const(HiRPC.Sender) sender);

    void consensus_failure(const(ConsensusException) e);
}

@safe
interface P2pNet
{
    void start_listening();
    void send(const(Pubkey) channel, const(HiRPC.Sender) doc);
    void close();
}

@safe
interface GossipNet : P2pNet
{
    alias ChannelFilter = bool delegate(const(Pubkey) channel) @safe;
    alias SenderCallBack = const(HiRPC.Sender) delegate() @safe;
    const(sdt_t) time() pure const nothrow;

    bool isValidChannel(const(Pubkey) channel) const nothrow;
    void add_channel(const(Pubkey) channel);
    void remove_channel(const(Pubkey) channel);
    const(Pubkey) gossip(const(ChannelFilter) channel_filter, const(SenderCallBack) sender);
    const(Pubkey) select_channel(const(ChannelFilter) channel_filter);
}

@safe
interface ScriptNet
{
    import std.concurrency;

    @property void transcript_tid(Tid tid);

    @property Tid transcript_tid() pure nothrow;

    @property void scripting_engine_tid(Tid tid);

    @property Tid scripting_engine_tid();
}
