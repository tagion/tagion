module tagion.gossip.GossipNet;

@safe:

import core.time;
import core.thread;

import std.random;
import std.algorithm;
import std.math : floor;

import tagion.actor;
import tagion.basic.Types;
import tagion.crypto.Types;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.logger;
import tagion.services.messages;
import tagion.utils.StdTime;


interface GossipNet {
    alias ChannelFilter = bool delegate(const(Pubkey) channel) @safe;
    alias SenderCallBack = const(HiRPC.Sender) delegate() @safe;
    const(sdt_t) time() const nothrow;

    bool isValidChannel(const(Pubkey) channel) const nothrow;
    void add_channel(const(Pubkey) channel);
    void remove_channel(const(Pubkey) channel);
    void send(const Pubkey channel, const(HiRPC.Sender) sender);
    const(Pubkey) gossip(const(ChannelFilter) channel_filter, const(SenderCallBack) sender);
    const(Pubkey) select_channel(const(ChannelFilter) channel_filter);
}

abstract class StdGossipNet : GossipNet {
    private string[immutable(Pubkey)] addresses;
    private immutable(Pubkey)[] _pkeys;
    immutable(Pubkey) mypk;
    Random random;

    this(const Pubkey mypk) {
        this.random = Random(unpredictableSeed);
        this.mypk = mypk;
    }

    void add_channel(const Pubkey channel) {
        import core.thread;
        import tagion.gossip.AddressBook;

        const address = addressbook[channel].get.address;

        _pkeys ~= channel;
        addresses[channel] = address;

        log.trace("Add channel: %s tid: %s", channel.encodeBase64, addresses[channel]);
    }

    void remove_channel(const Pubkey channel) {
        import std.algorithm.searching;

        const channel_index = countUntil(_pkeys, channel);
        _pkeys = _pkeys[0 .. channel_index] ~ _pkeys[channel_index + 1 .. $];
        addresses.remove(channel);
    }

    const(sdt_t) time() const nothrow {
        import std.exception : assumeWontThrow;
        return assumeWontThrow(currentTime);
    }

    bool isValidChannel(const(Pubkey) channel) const pure nothrow {
        return (channel in addresses) !is null;
    }

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
}

private void sleep(Duration dur) @trusted {
    Thread.sleep(dur);
}

class EmulatorGossipNet : StdGossipNet {
    uint delay;
    this(const Pubkey mypk, uint avrg_delay_msecs) {
        this.delay = avrg_delay_msecs;
        super(mypk);
    }

    void send(const Pubkey channel, const(HiRPC.Sender) sender) {

        import tagion.utils.pretend_safe_concurrency;
        import std.algorithm.searching : countUntil;
        import tagion.hibon.HiBONJSON;

        version(RANDOM_DELAY) {
            sleep((cast(int)uniform(0.5f, 1.5f, random) * delay).msecs);
        } else {
            sleep(delay.msecs);
        }

        auto node_tid = locate(addresses[channel]);
        if (node_tid is Tid.init) {
            return;
        }

        node_tid.send(ReceivedWavefront(), sender.toDoc);
        version (EPOCH_LOG) {
            log.trace("Successfully sent to %s (Node_%s) %d bytes", channel.encodeBase64, _pkeys.countUntil(channel), sender.toDoc.serialize.length);
        }
    }
}

class NNGGossipNet : StdGossipNet {
    uint delay;
    private ActorHandle nodeinterface;
    this(const Pubkey mypk, uint avrg_delay_msecs, ActorHandle nodeinterface) {
        this.nodeinterface = nodeinterface;
        this.delay = avrg_delay_msecs;
        super(mypk);
    }
    void send(const Pubkey channel, const(HiRPC.Sender) sender) {
        sleep((cast(int)uniform(0.5f, 1.5f, random) * delay).msecs);

        nodeinterface.send(NodeSend(), channel, cast(Document)sender.toDoc);
    }
}
