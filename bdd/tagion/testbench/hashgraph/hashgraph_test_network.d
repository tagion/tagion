/// Consensus HashGraph main object 
module tagion.testbench.hashgraph.hashgraph_test_network;

import std.format;
import std.range;
import std.algorithm;

import tagion.logger.Logger : log;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Event;
import tagion.communication.HiRPC;
import tagion.utils.StdTime;
import tagion.utils.Miscellaneous : cutHex;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.hibon.HiBON;
import std.stdio;
import std.exception : assumeWontThrow;
import core.memory : pageSize;
import tagion.utils.BitMask;
import std.conv;
import tagion.hashgraph.Refinement;
import std.typecons;




class TestRefinement : StdRefinement { 

    struct ExcludedNodesHistory {
        Pubkey pubkey;
        bool state;
        int round;
        bool stop_communication;   
    }
    static ExcludedNodesHistory[] excluded_nodes_history;


    struct Epoch {
        Event[] events;
        sdt_t epoch_time;
        Round decided_round;
    }

    static Epoch[][Pubkey] epoch_events;
    override void finishedEpoch(const(Event[]) events, const sdt_t epoch_time, const Round decided_round) {
        
        auto epoch = (() @trusted => Epoch(cast(Event[]) events, epoch_time, cast(Round)decided_round))(); 
        epoch_events[hashgraph.owner_node.channel] ~= epoch;
    }

    override void excludedNodes(ref BitMask excluded_mask) {
        import tagion.basic.Debug;
        import std.algorithm : filter;
        if (excluded_nodes_history is null) { return; }
                
        const last_decided_round = hashgraph.rounds.last_decided_round.number;

        auto histories = excluded_nodes_history.filter!(h => h.round == last_decided_round);
        foreach(history; histories) {
            const node = hashgraph.nodes.get(history.pubkey, HashGraph.Node.init);
            if (node !is HashGraph.Node.init) {
                excluded_mask[node.node_id] = history.state;
                __write("setting exclude mask");
            }
        }
        __write("callback<%s>", excluded_mask);

    }

}





/++
    This function makes sure that the HashGraph has all the events connected to this event
+/
@safe
static class TestNetwork { //(NodeList) if (is(NodeList == enum)) {
    import core.thread.fiber : Fiber;
    import tagion.crypto.SecureNet : StdSecureNet;

    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.gossip.InterfaceNet : GossipNet;
    import tagion.utils.Random;
    import tagion.utils.Queue;
    import tagion.hibon.HiBONJSON;
    import std.datetime.systime : SysTime;
    import core.time;

    TestGossipNet authorising;
    Random!size_t random;
    SysTime global_time;
    enum timestep {
        MIN = 50,
        MAX = 150
    }


    static const(SecureNet) verify_net;
    static this() {
        verify_net = new StdSecureNet();
    }

    Pubkey current;

    alias ChannelQueue = Queue!Document;
    class TestGossipNet : GossipNet {
        import tagion.hashgraph.HashGraphBasic;

        ChannelQueue[Pubkey] channel_queues;
        sdt_t _current_time;

        static bool[Pubkey] online_states;

               
        void start_listening() {
            // empty
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
            return (channel in channel_queues) !is null;
        }

        void send(const(Pubkey) channel, const(HiRPC.Sender) sender) {
            if (online_states !is null && !online_states[channel]) { return; }

            const doc = sender.toDoc;
            channel_queues[channel].write(doc);
        }

        void send(const(Pubkey) channel, const(Document) doc) nothrow {
            if (online_states !is null && !online_states[channel]) { return; }

            channel_queues[channel].write(doc);
        }

        final void send(T)(const(Pubkey) channel, T pack) if (isHiBONRecord!T) {
            if (online_states !is null && !online_states[channel]) { return; }

            send(channel, pack.toDoc);
        }

        const(Document) receive(const Pubkey channel) nothrow {
            return channel_queues[channel].read;
        }

        void close() {
            // Dummy empty
        }

        const(Pubkey) select_channel(ChannelFilter channel_filter) {
            foreach (count; 0 .. channel_queues.length / 2) {


                const node_index = random.value(0, channel_queues.length);

                auto send_channels = channel_queues
                    .byKey
                    .dropExactly(node_index)
                    .filter!((k) => online_states[k]);

                if (!send_channels.empty && channel_filter(send_channels.front)) {
                    return send_channels.front;
                }
            }
            return Pubkey();
        }

        const(Pubkey) gossip(
                ChannelFilter channel_filter,
                SenderCallBack sender) {
            const send_channel = select_channel(channel_filter);
            if (send_channel.length) {
                send(send_channel, sender());
            }
            return send_channel;
        }

        bool empty(const Pubkey channel) const pure nothrow {
            return channel_queues[channel].empty;
        }

        void add_channel(const Pubkey channel) {
            channel_queues[channel] = new ChannelQueue;
        }

        void remove_channel(const Pubkey channel) {
            channel_queues.remove(channel);
        }
    }

    class FiberNetwork : Fiber {
        HashGraph _hashgraph;
        //immutable(string) name;
        @trusted
        this(HashGraph h, const(ulong) stacksize = pageSize * Fiber.defaultStackPages) nothrow
        in {
            assert(_hashgraph is null);
        }
        do {
            super(&run, stacksize);
            _hashgraph = h;
        }

        const(HashGraph) hashgraph() const pure nothrow {
            return _hashgraph;
        }

        sdt_t time() {
            const systime = global_time + random.value(timestep.MIN, timestep.MAX).msecs;
            const sdt_time = sdt_t(systime.stdTime);
            return sdt_time;
        }

        private void run() {
            { // Eva Event
                immutable buf = cast(Buffer) _hashgraph.channel;
                const nonce = cast(Buffer) _hashgraph.hirpc.net.calcHash(buf);
                writefln("NODE SIZE OF TEST HASHGRAPH %s", _hashgraph.node_size);
                auto eva_event = _hashgraph.createEvaEvent(time, nonce);

            }
            uint count;
            bool stop;

            const(Document) payload() @safe {
                auto h = new HiBON;
                h["node"] = format("%s-%d", _hashgraph.name, count);
                return Document(h);
            }

            while (!stop) {
                while (!authorising.empty(_hashgraph.channel)) {
                    if (current !is Pubkey.init && TestGossipNet.online_states !is null && !TestGossipNet.online_states[current]) {
                        (() @trusted { yield; })();
                    }

                    const received = _hashgraph.hirpc.receive(
                            authorising.receive(_hashgraph.channel));
                    _hashgraph.wavefront(
                            received,
                            time,
                            (const(HiRPC.Sender) return_wavefront) @safe {
                            authorising.send(received.pubkey, return_wavefront);
                            },
                            &payload
                    );
                    count++;
                }
                (() @trusted { yield; })();
                //const onLine=_hashgraph.areWeOnline;
                const init_tide = random.value(0, 2) is 1;
                if (init_tide) {
                    _hashgraph.init_tide(
                            &authorising.gossip,
                            &payload,
                            time);
                    count++;
                }
            }
        }
    }

    @trusted
    const(Pubkey[]) channels() const pure nothrow {
        return networks.keys;
    }

    bool allInGraph() {
        return networks
            .byValue
            .map!(n => n._hashgraph.areWeInGraph)
            .all!(s => s);
    }

    static bool testing;
    void addNode(immutable(ulong) N, const(string) name, const Flag!"joining" joining = No.joining) {
        immutable passphrase = format("very secret %s", name);
        auto net = new StdSecureNet();
        net.generateKeyPair(passphrase);
        auto refinement = new TestRefinement;
        
        auto h = new HashGraph(N, net, refinement, &authorising.isValidChannel, joining, name);
        if (!testing) {
            h.__debug_print=testing=true;
        }
        h.scrap_depth = 0;
        writefln("Adding Node: %s with %s", name, net.pubkey.cutHex);
        networks[net.pubkey] = new FiberNetwork(h, pageSize * 1024);
        authorising.add_channel(net.pubkey);
        TestGossipNet.online_states[net.pubkey] = true;
    }

    void swapNode(immutable(ulong) N, const Pubkey out_channel, const string new_node) {
        authorising.remove_channel(out_channel);
    }

    FiberNetwork[Pubkey] networks;
    this(const(string[]) node_names) {
        authorising = new TestGossipNet;
        immutable N = node_names.length; //EnumMembers!NodeList.length;
        node_names.each!(name => addNode(N, name));
    }
}

import tagion.hashgraphview.Compare;
bool event_error(const Event e1, const Event e2, const Compare.ErrorCode code) @safe nothrow {
    static string print(const Event e) nothrow {
        if (e) {
            const round_received = (e.round_received) ? e.round_received.number.to!string : "#";
            return assumeWontThrow(format("(%d:%d:%d:r=%d:rr=%s:%s)",
                    e.id, e.node_id, e.altitude, e.round.number, round_received,
                    e.fingerprint.cutHex));
        }
        return assumeWontThrow(format("(%d:%d:%s:%s)", 0, -1, 0, "nil"));
    }

    assumeWontThrow(writefln("Event %s and %s %s", print(e1), print(e2), code));
    return false;
}


@safe
void printStates(TestNetwork network) {
    foreach(channel; network.networks) {
        writeln("----------------------");
        foreach (channel_key; network.channels) {
            const current_hashgraph = network.networks[channel_key]._hashgraph;
            // writef("%16s %10s ingraph:%5s|", channel_key.cutHex, current_hashgraph.owner_node.sticky_state, current_hashgraph.areWeInGraph);
            foreach (receiver_key; network.channels) {
                const node = current_hashgraph.nodes.get(receiver_key, null);                
                const state = (node is null) ? ExchangeState.NONE : node.state;
                writef("%15s %s", state, node is null ? "X" : " ");
            }
            writeln;
        }
    }

}

