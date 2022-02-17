module tagion.gossip.EmulatorGossipNet;

import std.stdio;
import std.concurrency;
import std.format;
import std.array : join;
import std.conv : to;

// import tagion.revision;
//import tagion.services.Options;
import tagion.basic.Basic : EnumText, Buffer, Pubkey, buf_idup, basename, isBufferType;

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

import tagion.basic.Logger;
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
        if (tid == thisTid) {
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
        immutable taskname = i.get_node_name;
        log("trying to locate: %s", taskname);
        auto tid = locate(taskname);
        return tid;
    }

    private Tid[immutable(Pubkey)] _tids;
    private immutable(Pubkey)[] _pkeys;
    protected uint _send_node_id;
    protected sdt_t _current_time;
    protected Pubkey mypk;
    Random random;
    this(const Pubkey mypk, Duration duration) {
        this.random = Random(unpredictableSeed);
        this.duration = duration;
    }

    void add_channel(const Pubkey channel) {
        _pkeys ~= channel;
        _tids[channel] = getTidByNodeNumber(node_counter);
        log("channel: %s tid: %s", channel.cutHex, _tids[channel]);
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
        return (channel in _tids) !is null && channel != mypk;
    }

    const(Pubkey) select_channel(ChannelFilter channel_filter) {
        import std.range : dropExactly;

        foreach (count; 0 .. _tids.length * 2) {
            const node_index = uniform(0, cast(uint) _tids.length, random);
            // log("selected index: %d %d", node_index, _tids.length);
            const send_channel = _pkeys[node_index];
            // log("trying to select: %s, valid?: %s", send_channel.cutHex, channel_filter(send_channel));
            if (channel_filter(send_channel)) {
                return send_channel;
            }
        }
        return Pubkey();
    }

    const(Pubkey) gossip(
            ChannelFilter channel_filter, SenderCallBack sender) {
        const send_channel = select_channel(channel_filter);
        log("selected channel: %s", send_channel.cutHex);
        if (send_channel.length) {
            send(send_channel, sender());
        }
        return send_channel;
    }

    //     void dump(const(HiBON[]) events) const {
    //         foreach(e; events) {
    //             auto pack_doc=Document(e.serialize);
    //             immutable pack=buildEventPackage(this, pack_doc);
    // //            immutable fingerprint=pack.event_body.fingerprint;
    //             log("\tsending %s f=%s a=%d", pack.pubkey.cutHex, pack.fingerprint.cutHex, pack.event_body.altitude);
    //         }
    //     }

    version (none) void dump(const(HiBON[]) events) const {
        foreach (e; events) {
            auto pack_doc = Document(e.serialize);
            immutable pack = buildEventPackage(this, pack_doc);
            //            immutable fingerprint=pack.event_body.fingerprint;
            log("\tsending %s f=%s a=%d", pack.pubkey.cutHex, pack.fingerprint.cutHex, pack
                    .event_body.altitude);
        }
    }

    @trusted
    void send(const Pubkey channel, const(HiRPC.Sender) sender) {
        import std.algorithm.searching : countUntil;
        import tagion.hibon.HiBONJSON;

        log.trace("send to %s (Node_%s) %d bytes", channel.cutHex, _pkeys.countUntil(channel), sender
                .toDoc.serialize.length);
        // log("%s", sender.toDoc.toJSON);
        // if ( callbacks ) {
        //     callbacks.send(channel, sender.toDoc);
        // }
        // log(_tids)
        Thread.sleep(duration);
        _tids[channel].send(sender.toDoc);
        log.trace("sended");
    }
}
