module tagion.gossip.EmulatorGossipNet;

import std.stdio;
import std.concurrency;
import std.format;
import std.array : join;
import std.conv : to;

import tagion.basic.Types : Buffer, isBufferType;
import tagion.basic.basic : EnumText, buf_idup, basename;
import tagion.crypto.Types : Pubkey;

//import tagion.TagionExceptions : convertEnum, consensusCheck, consensusCheckArguments;
import tagion.utils.Miscellaneous : cutHex;

// import tagion.utils.Random;
import tagion.utils.LRU;
import tagion.utils.Queue;

//import tagion.Keywords;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.gossip.InterfaceNet;

// import tagion.gossip.GossipNet;
//import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Event;
import tagion.basic.ConsensusExceptions;

import tagion.logger.Logger;
import tagion.options.ServiceNames : get_node_name;
import tagion.options.CommonOptions;

import tagion.utils.StdTime;
import tagion.communication.HiRPC;
import tagion.crypto.secp256k1.NativeSecp256k1;
import core.atomic;
import std.random : Random, unpredictableSeed, uniform;
import core.time;
import std.datetime;
import core.thread;
import tagion.services.messages;

@safe
class EmulatorGossipNet : GossipNet {
    private Duration duration;

    private Tid[immutable(Pubkey)] _tids;
    private immutable(Pubkey)[] _pkeys;
    protected uint _send_node_id;
    protected sdt_t _current_time;
    immutable(Pubkey) mypk;
    Random random;

    this(const Pubkey mypk, Duration duration) {
        this.random = Random(unpredictableSeed);
        this.duration = duration;
        this.mypk = mypk;
    }

    void add_channel(const Pubkey channel) {
        import tagion.gossip.AddressBook;
        import core.thread;
        import tagion.services.locator;

        const task_name = addressbook.getAddress(channel);

        auto task_id = tryLocate(task_name);

        _pkeys ~= channel;
        _tids[channel] = task_id;

        log.trace("Add channel: %s tid: %s", channel.cutHex, _tids[channel]);
    }

    void remove_channel(const Pubkey channel) {
        import std.algorithm.searching;

        const channel_index = countUntil(_pkeys, channel);
        _pkeys = _pkeys[0 .. channel_index] ~ _pkeys[channel_index + 1 .. $];
        _tids.remove(channel);
    }

    @safe
    void close() {

    }

    @property
    const(sdt_t) time() pure const {
        return _current_time;
    }

    bool isValidChannel(const(Pubkey) channel) const pure nothrow {
        return (channel in _tids) !is null;
    }

    const(Pubkey) select_channel(const(ChannelFilter) channel_filter) {
        import std.range : dropExactly;

        foreach (count; 0 .. _tids.length * 2) {
            const node_index = uniform(0, cast(uint) _tids.length, random);
            const send_channel = _pkeys[node_index];
            if ((send_channel != mypk) && channel_filter(send_channel)) {
                return send_channel;
            }
        }
        return Pubkey();
    }

    const(Pubkey) gossip(
            const(ChannelFilter) channel_filter,
            const(SenderCallBack) sender) {
        const send_channel = select_channel(channel_filter);
        version(EPOCH_LOG) {
            log.trace("Selected channel: %s", send_channel.cutHex);
        }
        if (send_channel.length) {
            send(send_channel, sender());
        }
        return send_channel;
    }

    @trusted
    void send(const Pubkey channel, const(HiRPC.Sender) sender) {
        import std.algorithm.searching : countUntil;
        import tagion.hibon.HiBONJSON;


        Thread.sleep(duration);
        _tids[channel].send(ReceivedWavefront(), sender.toDoc);
        version(EPOCH_LOG) {
        log.trace("Successfully sent to %s (Node_%s) %d bytes", channel.cutHex, _pkeys.countUntil(channel), sender
                .toDoc.serialize.length);
        }
    }

    void start_listening() {
        // NO IMPLEMENTATION NEEDED
    }
}
