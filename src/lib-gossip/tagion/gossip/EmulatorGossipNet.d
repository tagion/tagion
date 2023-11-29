module tagion.gossip.EmulatorGossipNet;

import std.array : join;
import std.concurrency;
import std.conv : to;
import std.format;
import std.stdio;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.basic.basic : EnumText, basename, buf_idup;
import tagion.crypto.Types : Pubkey;

import tagion.utils.Miscellaneous : cutHex;

import tagion.utils.LRU;
import tagion.utils.Queue;


import tagion.gossip.InterfaceNet;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;

import tagion.basic.ConsensusExceptions;
import tagion.communication.HiRPC;
import tagion.hashgraph.Event;
import tagion.logger.Logger;
import tagion.options.CommonOptions;
import tagion.options.ServiceNames : get_node_name;
import tagion.utils.StdTime;
import tagion.crypto.secp256k1.NativeSecp256k1;
import core.atomic;
import core.thread;
import core.time;
import std.datetime;
import std.random : Random, uniform, unpredictableSeed;
import tagion.services.messages;

@safe
class EmulatorGossipNet : GossipNet {
    private Duration duration;

    private string[immutable(Pubkey)] task_names;
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
        import core.thread;
        import tagion.gossip.AddressBook;
        import tagion.services.locator;

        const task_name = addressbook.getAddress(channel);

        // we do this command to make sure that everything has started since it will throw if it has not been started.
        tryLocate(task_name);

        _pkeys ~= channel;
        task_names[channel] = task_name;

        log.trace("Add channel: %s tid: %s", channel.cutHex, task_names[channel]);
    }

    void remove_channel(const Pubkey channel) {
        import std.algorithm.searching;

        const channel_index = countUntil(_pkeys, channel);
        _pkeys = _pkeys[0 .. channel_index] ~ _pkeys[channel_index + 1 .. $];
        task_names.remove(channel);
    }

    @safe
    void close() {

    }

    @property
    const(sdt_t) time() pure const {
        return _current_time;
    }

    bool isValidChannel(const(Pubkey) channel) const pure nothrow {
        return (channel in task_names) !is null;
    }

    const(Pubkey) select_channel(const(ChannelFilter) channel_filter) {
        import std.range : dropExactly;

        foreach (count; 0 .. task_names.length * 2) {
            const node_index = uniform(0, cast(uint) task_names.length, random);
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

        auto node_tid = locate(task_names[channel]);
        if (node_tid is Tid.init) {
            return;
        }
        
        node_tid.send(ReceivedWavefront(), sender.toDoc);
        version(EPOCH_LOG) {
        log.trace("Successfully sent to %s (Node_%s) %d bytes", channel.cutHex, _pkeys.countUntil(channel), sender
                .toDoc.serialize.length);
        }
    }

    void start_listening() {
        // NO IMPLEMENTATION NEEDED
    }
}
