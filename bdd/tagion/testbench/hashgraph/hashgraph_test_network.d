/// Consensus HashGraph main object 
module tagion.testbench.hashgraph.hashgraph_test_network;

import core.memory : pageSize;
import std.algorithm;
import std.conv;
import std.exception : assumeWontThrow;
import std.format;
import std.range;
import std.stdio;
import std.typecons;
import tagion.basic.Types : Buffer;
import tagion.communication.HiRPC;
import tagion.crypto.Types;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Refinement;
import tagion.hashgraph.RefinementInterface;
import tagion.hashgraph.Round;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONRecord : isHiBONRecord;
import tagion.logger.Logger : log;
import tagion.services.options;
import tagion.utils.BitMask;
import tagion.utils.Miscellaneous : cutHex;
import tagion.utils.StdTime;
import tagion.behaviour.BehaviourException : check;

class TestRefinement : StdRefinement {

    struct Swap {
        Pubkey swap_out;
        Pubkey swap_in;
        int round;
    }

    static Swap swap;

    struct Epoch {
        Event[] events;
        sdt_t epoch_time;
        Round decided_round;
    }

    static Epoch[][Pubkey] epoch_events;
    override void finishedEpoch(const(Event[]) events, const sdt_t epoch_time, const Round decided_round) const {

        auto epoch = (() @trusted => Epoch(cast(Event[]) events, epoch_time, cast(Round) decided_round))();
        epoch_events[hashgraph.owner_node.channel] ~= epoch;
    }

}
class NewTestRefinement : StdRefinement {
    static FinishedEpoch[string][long] epochs;



    override void epoch(Event[] event_collection, const Round decided_round) const {
        static bool first_epoch;
        if (!first_epoch) {
            check(event_collection.all!(e => e.round_received !is null && e.round_received.number != long.init), "should have a round received");
        } 
        first_epoch = true;
        
        import std.range : tee;
        sdt_t[] times;
        auto events = event_collection
            .tee!((e) => times ~= e.event_body.time)
            .filter!((e) => !e.event_body.payload.empty)
            .array;

        version(OLD_ORDERING) {
            auto sorted_events = events.sort!((a,b) => order_less(a, b, MAX_ORDER_COUNT)).array;
        }
        version(NEW_ORDERING) {
            const famous_witnesses = decided_round
                ._events
                .filter!(e => e !is null)
                .filter!(e => decided_round.famous_mask[e.node_id])
                .array;
            auto sorted_events = events.sort!((a,b) => order_less(a,b, famous_witnesses, decided_round)).array;
        }
        times.sort;
        
        version(OLD_ORDERING) {
            const mid = times.length / 2 + (times.length % 1);
            const epoch_time = times[mid];
        }
        version(NEW_ORDERING) {
            const epoch_time = times[times.length / 2];
        }
        version(OLD_ORDERING) {
            auto __sorted_raw_events = event_collection.sort!((a,b) => order_less(a, b, MAX_ORDER_COUNT)).array;
        }
        version(NEW_ORDERING) {
            const famous_witnesses = decided_round
                ._events
                .filter!(e => e !is null)
                .filter!(e => decided_round.famous_mask[e.node_id])
                .array;
            auto __sorted_raw_events = event_collection.sort!((a,b) => order_less(a,b, famous_witnesses, decided_round)).array;
        }
        auto event_payload = FinishedEpoch(__sorted_raw_events, epoch_time, decided_round.number);

        epochs[event_payload.epoch][format("%(%02x%)", hashgraph.owner_node.channel)] = event_payload;

        checkepoch(hashgraph.nodes.length.to!uint, epochs);
    }

}

alias TestNetwork = TestNetworkT!TestRefinement;
/++
    This function makes sure that the HashGraph has all the events connected to this event
+/
@safe
static class TestNetworkT(R) if(is (R:Refinement)) { //(NodeList) if (is(NodeList == enum)) {
    import core.thread.fiber : Fiber;
    import core.time;
    import std.datetime.systime : SysTime;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.crypto.SecureNet : StdSecureNet;
    import tagion.gossip.GossipNet;
    import tagion.hibon.HiBONJSON;
    import tagion.utils.Queue;
    import tagion.utils.Random;

    TestGossipNet authorising;
    Random!size_t random;
    SysTime global_time;
    enum timestep {
        MIN = 50,
        MAX = 150
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
            if (online_states !is null && !online_states[channel]) {
                return;
            }

            const doc = sender.toDoc;
            channel_queues[channel].write(doc);
        }

        void send(const(Pubkey) channel, const(Document) doc) nothrow {
            if (online_states !is null && !online_states[channel]) {
                return;
            }

            channel_queues[channel].write(doc);
        }

        final void send(T)(const(Pubkey) channel, T pack) if (isHiBONRecord!T) {
            if (online_states !is null && !online_states[channel]) {
                return;
            }

            send(channel, pack.toDoc);
        }

        const(Document) receive(const Pubkey channel) nothrow {
            return channel_queues[channel].read;
        }

        void close() {
            // Dummy empty
        }

        const(Pubkey) select_channel(ChannelFilter channel_filter) {
            auto send_channels = channel_queues
                .byKey
                .filter!(k => online_states[k])
                .filter!(k => channel_filter(k))
                .array;

            if (!send_channels.empty) {
                const node_index = random.value(0, send_channels.length); 
                return send_channels[node_index];
            }

            
            return Pubkey.init;
        }

        const(Pubkey) gossip(
                ChannelFilter channel_filter,
                SenderCallBack sender) {
            const send_channel = select_channel(channel_filter);
            if (send_channel != Pubkey.init) {
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
                if (Event.callbacks) {
                    Event.callbacks.connect(eva_event);
                }

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

    static int testing;
    void addNode(Refinement refinement, immutable(ulong) N, const(string) name, int scrap_depth = 0, const Flag!"joining" joining = No.joining) {
        immutable passphrase = format("very secret %s", name);
        auto net = new StdSecureNet();
        net.generateKeyPair(passphrase);

        auto h = new HashGraph(N, net, refinement, &authorising.isValidChannel, joining, name);
        if (testing < 4) {
            testing++;
            if (testing == 1) {
                h.__debug_print = true;
            }
        }
        h.scrap_depth = scrap_depth;
        writefln("Adding Node: %s with %s", name, net.pubkey.cutHex);
        networks[net.pubkey] = new FiberNetwork(h, pageSize * 1024);

        authorising.add_channel(net.pubkey);
        TestGossipNet.online_states[net.pubkey] = true;
    }

    FiberNetwork[Pubkey] networks;
    this(const(string[]) node_names, int scrap_depth = 0) {
        authorising = new TestGossipNet;
        immutable N = node_names.length; //EnumMembers!NodeList.length;
        node_names.each!(name => addNode(new R, N, name, scrap_depth));
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
void printStates(R)(TestNetworkT!(R) network) if (is (R:Refinement)) {
    foreach (channel; network.networks) {
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


@safe
static void checkepoch(uint number_of_nodes, ref FinishedEpoch[string][long] epochs) {
    import tagion.crypto.SecureNet : StdSecureNet, StdHashNet;
    import tagion.crypto.SecureInterfaceNet;

    writefln("unfinished epochs %s", epochs.length);
    foreach (epoch; epochs.byKeyValue) {
        if (epoch.value.length == number_of_nodes) {
            HashNet net = new StdHashNet;
            // check that all epoch numbers are the same
            check(epoch.value.byValue.map!(finished_epoch => finished_epoch.epoch).uniq.walkLength == 1, "not all epoch numbers were the same!");

            
            const(EventPackage)[][] all_node_events = epoch.value.byValue.map!(finished_epoch => finished_epoch.event_packages).array;
            const(EventPackage)[] not_the_same;
            foreach(i, node_events; all_node_events[0..$-1]) {
                foreach(to_compare; all_node_events[i+1..$]) {
                    foreach(e; node_events) {
                        if (!to_compare.canFind(e)) {
                            not_the_same ~= e;
                            // DO SOME CALLBACK
                        }
                    }
                    foreach(e; to_compare) {
                        if (!node_events.canFind(e)) {
                            not_the_same ~= e;
                            //do some callback
                        }
                    }
                }
            }
            const(EventPackage)[] not_the_same_uniq = not_the_same.uniq!((a,b) => net.calcHash(a) == net.calcHash(b)).array;
            foreach(j, e; not_the_same_uniq) {
                writefln("%s:%(%02x%)", j, net.calcHash(e));
            }

            // check all events are the same
            auto epoch_events = epoch.value.byValue.map!(finished_epoch => finished_epoch.event_packages).array;
            string print_events() {
                string printout;
                // printout ~= format("EPOCH: %s", epoch.value.epoch);
                foreach(i, events; epoch_events) {
                    uint number_of_empty_events;
                    printout ~= format("\n%s: ", i);
                    foreach(epack; events) {
                        printout ~= format("%(%02x%) ", net.calcHash(epack)[0..4]);
                        if (epack.event_body.payload.empty) {
                            number_of_empty_events++;
                        }
                    }
                    printout ~= format("TOTAL: %s EMPTY: %s", events.length, number_of_empty_events);
                }
                return printout;
            }

            if (!epoch_events.all!(e => e == epoch_events[0])) {
                check(0, format("not all events the same on epoch %s \n%s", epoch.key, print_events));
            }

            auto timestamps = epoch.value.byValue.map!(finished_epoch => finished_epoch.time).array; 
            if (!timestamps.all!(t => t == timestamps[0])) {
                string text;
                foreach(i, t; timestamps) {
                    auto line = format("\n%s: %s", i, t);
                    text ~= line;
                }
                check(0, format("not all timestamps were the same!\n%s\n%s", text, print_events));
            }

            writefln("FINISHED ENTIRE EPOCH %s", epoch.key);
            epochs.remove(epoch.key);
        }
    }
}
