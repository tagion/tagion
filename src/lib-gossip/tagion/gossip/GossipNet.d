/// Gossipnet used for communication between nodes
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
    const(sdt_t) time() const nothrow;
    void add_channel(const(Pubkey) channel);
    void remove_channel(const(Pubkey) channel);
    void send(Pubkey channel, const(HiRPC.Sender) sender);
    const(Pubkey)[] active_channels() nothrow;
    ref Random random() pure nothrow;
}

abstract class StdGossipNet : GossipNet {
    private string[immutable(Pubkey)] addresses;
    private immutable(Pubkey)[] _pkeys;
    Random _random;

    this() {
        this._random = Random(unpredictableSeed);
    }

    const(Pubkey)[] active_channels() nothrow {
        return _pkeys;
    }

    ref Random random() pure nothrow {
        return _random;
    }

    void add_channel(const Pubkey channel) {
        import core.thread;
        import tagion.gossip.AddressBook;

        const address = addressbook[channel].get.address;

        _pkeys ~= channel;
        addresses[channel] = address;

        log.trace("Add channel: %s addr: %s", channel.encodeBase64, addresses[channel]);
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

    void send(WavefrontReq req, Pubkey channel, const(HiRPC.Sender) sender);

    void send(Pubkey channel, const(HiRPC.Sender) sender) {
        send(WavefrontReq(), channel, sender);
    }
}

private void sleep(Duration dur) @trusted {
    Thread.sleep(dur);
}

class EmulatorGossipNet : StdGossipNet {
    uint delay;
    this(uint avrg_delay_msecs) {
        this.delay = avrg_delay_msecs;
        super();
    }

    override void send(WavefrontReq req, Pubkey channel, const(HiRPC.Sender) sender) {
        import tagion.utils.pretend_safe_concurrency;
        import std.algorithm.searching : countUntil;
        import tagion.hibon.HiBONJSON;

        version (RANDOM_DELAY) {
            sleep((cast(int) uniform(0.5f, 1.5f, random) * delay).msecs);
        }
        else {
            sleep(delay.msecs);
        }

        auto node_tid = locate(addresses[channel]);
        if (node_tid is Tid.init) {
            return;
        }

        node_tid.send(WavefrontReq(req.id), sender.toDoc);
        debug (EPOCH_LOG) {
            log.trace("sending to %s (Node_%s) %d bytes", channel.encodeBase64, _pkeys.countUntil(channel), sender
                    .toDoc.serialize.length);
        }
    }
}

class NNGGossipNet : StdGossipNet {
    uint delay;
    private ActorHandle nodeinterface;
    this(uint avrg_delay_msecs, ActorHandle nodeinterface) {
        this.random = Random(unpredictableSeed);
        this.nodeinterface = nodeinterface;
        this.delay = avrg_delay_msecs;
        super();
    }

    override void send(WavefrontReq req, Pubkey channel, const(HiRPC.Sender) sender) {
        sleep((cast(int) uniform(0.5f, 1.5f, random) * delay).msecs);

        nodeinterface.send(WavefrontReq(req.id), channel, sender.toDoc);
    }
}
