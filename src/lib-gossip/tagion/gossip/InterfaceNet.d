module tagion.gossip.InterfaceNet;

import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraphBasic;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord : isHiBONRecord;

//import tagion.utils.Queue;
import tagion.basic.ConsensusExceptions;
import tagion.communication.HiRPC;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
import tagion.crypto.Types : Pubkey;
import tagion.utils.StdTime;

alias check = consensusCheck!(GossipConsensusException);
alias consensus = consensusCheckArguments!(GossipConsensusException);

@safe
interface P2pNet {
    void start_listening();
    void send(const(Pubkey) channel, const(HiRPC.Sender) doc);
    void close();
}

@safe
interface GossipNet : P2pNet {
    alias ChannelFilter = bool delegate(const(Pubkey) channel) @safe;
    alias SenderCallBack = const(HiRPC.Sender) delegate() @safe;
    const(sdt_t) time() const nothrow;

    bool isValidChannel(const(Pubkey) channel) const nothrow;
    void add_channel(const(Pubkey) channel);
    void remove_channel(const(Pubkey) channel);
    const(Pubkey) gossip(const(ChannelFilter) channel_filter, const(SenderCallBack) sender);
    const(Pubkey) select_channel(const(ChannelFilter) channel_filter);
}
