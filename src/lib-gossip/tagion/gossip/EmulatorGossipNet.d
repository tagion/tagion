module tagion.gossip.EmulatorGossipNet;

import std.stdio;
import std.concurrency;
import std.format;
import std.array : join;
import std.conv : to;

import tagion.revision;
import tagion.Options;
import tagion.basic.Basic : EnumText, Buffer, Pubkey, buf_idup,  basename, isBufferType;
//import tagion.TagionExceptions : convertEnum, consensusCheck, consensusCheckArguments;
import tagion.utils.Miscellaneous: cutHex;
import tagion.utils.Random;
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
import tagion.ServiceNames : get_node_name;

import tagion.utils.StdTime;
import tagion.communication.HiRPC;
import tagion.crypto.secp256k1.NativeSecp256k1;
import core.atomic;

@trusted
static uint getTids(Tid[] tids) {
    uint result=uint.max;
    foreach(i, ref tid ; tids) {
        immutable uint_i=cast(uint)i;
        immutable taskname=get_node_name(*options, uint_i);
        tid=locate(taskname);
        if ( tid == thisTid ) {
            result=uint_i;
        }
    }
    return result;
}

@trusted 
static Tid getTid(uint i){
    immutable taskname=get_node_name(*options, i);
    auto tid=locate(taskname);
    return tid;
}

private static shared uint node_counter = 0;
@safe
class EmulatorGossipNet : GossipNet {
    private Tid[immutable(Pubkey)] _tids;
    private immutable(Pubkey)[] _pkeys;
    protected uint _send_node_id;
    protected sdt_t _current_time;

    Random!uint random;

    void add_channel(const Pubkey channel) {
        atomicOp!"+="(node_counter, 1);
        _pkeys~=channel;
        _tids[channel] = getTid(node_counter);
    }

    void remove_channel(const Pubkey channel) {
        import std.algorithm.searching;
        const channel_index = countUntil(_pkeys, channel);
        _pkeys= _pkeys[0..channel_index] ~ _pkeys[channel_index+1 .. $];
        _tids.remove(channel);
    }
    
    @safe
    void close(){

    }

    @property
    void time(const(sdt_t) t) {
        _current_time=sdt_t(t);
    }

    @property
    const(sdt_t) time() pure const {
        return _current_time;
    }

    bool isValidChannel(const(Pubkey) channel) const pure nothrow {
        return (channel in _tids) !is null;
    }

    const(Pubkey) select_channel(ChannelFilter channel_filter) {
        import std.range : dropExactly;
        foreach(count; 0.._tids.length/2) {
            const node_index=random.value(0, cast(uint)_tids.length);
            const send_channel = _tids
                .byKey
                .dropExactly(node_index)
                .front;
            if (channel_filter(send_channel)) {
                return send_channel;
            }
        }
        return Pubkey();
    }

    const(Pubkey) gossip(
        ChannelFilter channel_filter, SenderCallBack sender) {
        const send_channel=select_channel(channel_filter);
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


    version(none)
    void dump(const(HiBON[]) events) const {
        foreach(e; events) {
            auto pack_doc=Document(e.serialize);
            immutable pack=buildEventPackage(this, pack_doc);
//            immutable fingerprint=pack.event_body.fingerprint;
            log("\tsending %s f=%s a=%d", pack.pubkey.cutHex, pack.fingerprint.cutHex, pack.event_body.altitude);
        }
    }

    protected uint _send_count;
    @trusted
    void send(const Pubkey channel, const(HiRPC.Sender) sender) {
        log.trace("send to %s %d bytes", channel.cutHex, sender.toDoc.serialize.length);
        // if ( callbacks ) {
        //     callbacks.send(channel, sender.toDoc);
        // }
        _tids[channel].send(sender.toDoc);
    }
}
