module tagion.gossip.NNGGossipNet;

import core.time;
import core.thread;

import std.random;
import std.math : floor;

import tagion.actor;
import tagion.basic.Types;
import tagion.crypto.Types;
import tagion.communication.HiRPC;
import tagion.gossip.InterfaceNet;
import tagion.hibon.Document;
import tagion.logger;
import tagion.services.messages;
import tagion.utils.StdTime;

@safe
class NNGGossipNet : GossipNet {
    private Duration duration;
    private uint duration_msecs;
    private string[Pubkey] addresses;
    private Pubkey[] _pkeys;
    immutable(Pubkey) mypk;
    protected sdt_t _current_time;
    private Random random;
    private ActorHandle nodeinterface;

    this(const Pubkey mypk, ActorHandle nodeinterface, uint duration) {
        this.nodeinterface = nodeinterface;
        this.random = Random(unpredictableSeed);
        this.mypk = mypk;
        this.duration_msecs = duration_msecs;
    }

    void add_channel(const Pubkey channel) {
        import tagion.gossip.AddressBook : addressbook;

        const address = addressbook[channel].get.address;
        _pkeys ~= channel;
        addresses[channel] = address;
    }

    void remove_channel(const Pubkey channel) {
        import std.algorithm.searching;

        const channel_index = countUntil(_pkeys, channel);
        _pkeys = _pkeys[0 .. channel_index] ~ _pkeys[channel_index + 1 .. $];
        addresses.remove(channel);
    }

    void close() {
    }

    @property
    const(sdt_t) time() const nothrow {
        import std.exception : assumeWontThrow;

        return assumeWontThrow(currentTime());
        /* return _current_time; */
    }

    bool isValidChannel(const(Pubkey) channel) const pure nothrow {
        return (channel in addresses) !is null;
    }

    // version(none) {
    const(Pubkey) select_channel(const(ChannelFilter) channel_filter) {
        import std.algorithm : filter;
        import std.array;

        assert(_pkeys.length > 1);
        auto keys_to_send = _pkeys.filter!(n => channel_filter(n) && n != mypk); 
        if (keys_to_send.empty) {
            log("NO AVAILABLE TO SEND TO");
            return Pubkey.init;
        }
        return choice(keys_to_send.array, random);
    }
    // }
    // else {
    // const(Pubkey) select_channel(const(ChannelFilter) channel_filter) {
    //     import std.range : dropExactly;

    //     foreach (count; 0 .. addresses.length * 2) {
    //         const node_index = uniform(0, cast(uint) addresses.length, random);
    //         const send_channel = _pkeys[node_index];
    //         if ((send_channel != mypk) && channel_filter(send_channel)) {
    //             return send_channel;
    //         }
    //     }
    //     return Pubkey();
    // }
    // }

    const(Pubkey) gossip(
            const(ChannelFilter) channel_filter,
            const(SenderCallBack) sender) {
        const send_channel = select_channel(channel_filter);
        version (EPOCH_LOG) {
            log.trace("Selected channel: %s", send_channel.encodeBase64);
        }
        if (send_channel.length) {
            send(send_channel, sender());
        }
        return send_channel;
    }

    void send(const Pubkey channel, const(HiRPC.Sender) sender) @trusted {

        Thread.sleep((cast(int)uniform(0.5f, 1.5f, random) * duration_msecs).msecs);

        nodeinterface.send(NodeSend(), channel, cast(Document)sender.toDoc);
    }

    void start_listening() {
        // NO IMPLEMENTATION NEEDED
    }
}
