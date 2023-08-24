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
import tagion.options.CommonOptions : CommonOptions;

import tagion.utils.StdTime;
import tagion.communication.HiRPC;
import tagion.crypto.secp256k1.NativeSecp256k1;
import core.atomic;
import std.random : Random, unpredictableSeed, uniform;
import core.time;
import std.datetime;
import core.thread;

@trusted
static uint getTids(Tid[] tids) {
    uint result = uint.max;
    foreach (i, ref tid; tids) {
        immutable uint_i = cast(uint) i;
        immutable taskname = uint_i.get_node_name;
        tid = locate(taskname);
        if (tid is thisTid) {
            result = uint_i;
        }
    }
    return result;
}

@safe
class EmulatorGossipNet : GossipNet {
    private uint node_counter = 0;
    private Duration duration;
    @trusted
    static Tid getTidByNodeNumber(const uint i) {
        writeln("in static getTidByNodeNumber");
        immutable taskname = i.get_node_name;
        log.trace("Trying to locate: %s", taskname);
        auto tid = locate(taskname);
        return tid;
    }

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
        writeln("in add channel");
        _pkeys ~= channel;
        _tids[channel] = getTidByNodeNumber(node_counter);
        log.trace("Add channel: %s tid: %s", channel.cutHex, _tids[channel]);
        node_counter++;
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
    void time(const(sdt_t) t) {
        _current_time = sdt_t(t);
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
        log.trace("Selected channel: %s", send_channel.cutHex);
        if (send_channel.length) {
            send(send_channel, sender());
        }
        return send_channel;
    }

    version (none) void dump(const(HiBON[]) events) const {
        foreach (e; events) {
            auto pack_doc = Document(e.serialize);
            immutable pack = buildEventPackage(this, pack_doc);
            log.trace("Sending %s f=%s a=%d", pack.pubkey.cutHex, pack.fingerprint.cutHex, pack
                    .event_body.altitude);
        }
    }

    @trusted
    void send(const Pubkey channel, const(HiRPC.Sender) sender) {
        import std.algorithm.searching : countUntil;
        import tagion.hibon.HiBONJSON;

        log("Send to %s (Node_%s) %d bytes", channel.cutHex, _pkeys.countUntil(channel), sender
                .toDoc.serialize.length);
        Thread.sleep(duration);
        _tids[channel].send(sender.toDoc);
        log.trace("Successfully sent to %s (Node_%s) %d bytes", channel.cutHex, _pkeys.countUntil(channel), sender
                .toDoc.serialize.length);
    }

    void start_listening() {
        // NO IMPLEMENTATION NEEDED
    }
}
