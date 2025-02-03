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
import tagion.utils.convert : cutHex;
import tagion.utils.StdTime;
import tagion.behaviour.BehaviourException : check, BehaviourException;

import tagion.basic.Debug;
import tagion.basic.Version;

@safe:
struct HashGraphOptions {
    uint number_of_nodes;
    uint seed = 123_456_689;
    string path;
    bool disable_graphfile; /// Disable graph file
    bool disable_name_order; /// Don't sort node name (Used to see the mask voting)
    bool continue_on_error; /// Don't stop if the epochs does not match
    int max_epochs;
}

class EpochTestRefinement : StdRefinement {

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

class TestRefinement : StdRefinement {
    static FinishedEpoch[string][long] epochs;
    static long last_epoch;
    static bool continue_on_error;
    override void epoch(Event[] event_collection, const Round decided_round) const {
        static bool first_epoch;
        if (!first_epoch) {
            check(event_collection.all!(e => e.round_received !is null && e.round_received.number != long.init), "should have a round received");
        }
        first_epoch = true;
        import tagion.basic.Debug : print = __write;
        print("%12s Round %04d event_collection=%d", hashgraph.name, decided_round.number, event_collection.length);
        if (event_collection.length == 0) {
            return;
        }

        auto times = event_collection.map!(e => cast(sdt_t) e.event_body.time).array;

        static if (ver.HASH_ORDERING) {
            auto sorted_events = event_collection.sort!((a, b) => a.fingerprint < b.fingerprint)
                .filter!((e) => !e.event_body.payload.empty)
                .array;
        }
        else static if (ver.OLD_ORDERING) {
            auto sorted_events = event_collection.sort!((a, b) => order_less(a, b, MAX_ORDER_COUNT))
                .filter!((e) => !e.event_body.payload.empty)
                .array;
        }
        else static if (ver.NEW_ORDERING) {
            const famous_witnesses = decided_round
                ._events
                .filter!(e => e !is null)
                .filter!(e => decided_round.famous_mask[e.node_id])
                .array;
            auto sorted_events = event_collection.sort!((a, b) => order_less(a, b, famous_witnesses, decided_round))
                .filter!((e) => !e.event_body.payload.empty)
                .array;
        }
        times.sort;
        const mid = times.length / 2 + (times.length % 1);
        const epoch_time = times[mid];

        static if (ver.HASH_ORDERING) {
            auto __sorted_raw_events = event_collection.sort!((a, b) => a.fingerprint < b.fingerprint).array;
        }
        else static if (ver.OLD_ORDERING) {
            auto __sorted_raw_events = event_collection.sort!((a, b) => order_less(a, b, MAX_ORDER_COUNT)).array;
        }
        else static if (ver.NEW_ORDERING) {
            const famous_witnesses = decided_round
                ._events
                .filter!(e => e !is null)
                .filter!(e => decided_round.famous_mask[e.node_id])
                .array;
            auto __sorted_raw_events = event_collection.sort!((a, b) => order_less(a, b, famous_witnesses, decided_round))
                .array;
        }
        auto finished_epoch = FinishedEpoch(__sorted_raw_events, epoch_time, decided_round.number);

        epochs[finished_epoch.epoch][format("%(%02x%)", hashgraph.owner_node.channel)] = finished_epoch;

        checkepoch(hashgraph.nodes.length.to!uint, epochs, last_epoch, continue_on_error);
    }

}

alias TestNetwork = TestNetworkT!TestRefinement;
/++
    This function makes sure that the HashGraph has all the events connected to this event
+/
static class TestNetworkT(R) if (is(R : Refinement)) { //(NodeList) if (is(NodeList == enum)) {
    import core.thread.fiber : Fiber;
    import core.time;
    import std.datetime.systime : SysTime;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.crypto.SecureNet : StdSecureNet;
    import tagion.gossip.GossipNet;
    import tagion.hibon.HiBONJSON;
    import tagion.utils.Queue;
    import std.random;

    TestGossipNet authorising;
    Random random;
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

        ref Random random() pure nothrow {
            return this.outer.random;
        }

        @property
        void time(const(sdt_t) t) {
            _current_time = sdt_t(t);
        }

        @property
        const(sdt_t) time() pure const {
            return _current_time;
        }

        void send(const(Pubkey) channel, const(HiRPC.Sender) sender) {
            send(channel, sender.toDoc);
        }

        void send(const(Pubkey) channel, const(Document) doc) nothrow {
            if (online_states !is null && !online_states[channel]) {
                return;
            }
            channel_queues[channel].write(doc);
        }

        final void send(T)(const(Pubkey) channel, T pack) if (isHiBONRecord!T) {
            send(channel, pack.toDoc);
        }

        const(Document) receive(const Pubkey channel) nothrow {
            return channel_queues[channel].read;
        }

        void close() {
            // Dummy empty
        }

        bool empty(const Pubkey channel) const pure nothrow {
            return channel_queues[channel].empty;
        }

        void add_channel(const Pubkey channel)
        in (!(channel in channel_queues), "Channel has ready been added")
        do {
            channel_queues[channel] = new ChannelQueue;
        }

        void remove_channel(const Pubkey channel) {
            channel_queues.remove(channel);
        }

        const(Pubkey[]) active_channels() pure nothrow {
            return channel_queues.keys;
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
            const systime = global_time + uniform(timestep.MIN, timestep.MAX, random).msecs;
            const sdt_time = sdt_t(systime.stdTime);
            return sdt_time;
        }

        private void run() {
            { // Eva Event
                immutable buf = cast(Buffer) _hashgraph.channel;
                const nonce = cast(Buffer) _hashgraph.hirpc.net.calcHash(buf);
                auto eva_event = _hashgraph.createEvaEvent(time, nonce);
                if (Event.callbacks) {
                    Event.callbacks.connect(eva_event);
                }

            }
            uint count;
            bool stop;

            const(Document) payload() {
                if (!_hashgraph.refinement.queue.empty) {
                    return _hashgraph.refinement.queue.read;
                }
                auto h = new HiBON;
                h["node"] = format("%s-%d", _hashgraph.name, count);
                count++;
                return Document(h);
            }

            void wavefront(
                    const HiRPC.Receiver received,
                    lazy const(sdt_t) time) {

                const response = _hashgraph.wavefront_response(received, time, payload());
                if (!response.isError) {
                    authorising.send(received.pubkey, response);
                }
            }

            while (!stop) {
                while (!authorising.empty(_hashgraph.channel)) {
                    if (current !is Pubkey.init && TestGossipNet.online_states !is null && !TestGossipNet.online_states[current]) {
                        (() @trusted { yield; })();
                    }

                    const received = _hashgraph.hirpc.receive(
                            authorising.receive(_hashgraph.channel));
                    wavefront(received, time);
                }
                (() @trusted { yield; })();
                const init_tide = uniform(0, 2, random) is 1;
                if (init_tide) {
                    authorising.send(
                            _hashgraph.select_channel, _hashgraph.create_init_tide(payload(), time));
                }
            }
        }
    }

    const(Pubkey[]) channels() const pure nothrow {
        return networks.keys;
    }

    bool allInGraph() {
        return networks
            .byValue
            .map!(n => n._hashgraph.areWeInGraph)
            .all!(s => s);
    }

    void addNode(Refinement refinement, immutable(ulong) N, const(string) name,
            int scrap_depth = 0) {
        immutable passphrase = format("very secret %s", name);
        auto net = new StdSecureNet();
        net.generateKeyPair(passphrase);
        refinement.queue = new PayloadQueue;
        auto h = new HashGraph(N, net, refinement, authorising, name);
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

bool event_error(const Event e1, const Event e2, const Compare.ErrorCode code) nothrow {
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

void printStates(R)(TestNetworkT!(R) network) if (is(R : Refinement)) {
    foreach (channel; network.networks) {
        writeln("----------------------");
        foreach (channel_key; network.channels) {
            const current_hashgraph = network.networks[channel_key]._hashgraph;
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
static void checkepoch(uint number_of_nodes, ref FinishedEpoch[string][long] epochs, ref long last_epoch, const bool continue_on_error = false) {
    static int error_count;
    import tagion.crypto.SecureNet : StdSecureNet, StdHashNet;
    import tagion.crypto.SecureInterfaceNet;
    import tagion.utils.Term;

    try {
        //writefln("unfinished epochs %s", epochs.length);
        foreach (epoch; epochs.byKeyValue) {
            if (epoch.value.length == number_of_nodes) {
                HashNet net = new StdHashNet;
                check(epoch.value.byValue.map!(finished_epoch => finished_epoch.epoch).uniq.walkLength == 1, "not all epoch numbers were the same!");

                const(Event)[][] all_node_events = epoch.value.byValue.map!(finished_epoch => finished_epoch.events)
                    .array;
                const(Event)[] not_the_same;
                foreach (i, node_events; all_node_events[0 .. $ - 1]) {
                    foreach (to_compare; all_node_events[i + 1 .. $]) {
                        foreach (event; node_events) {
                            if (!to_compare.map!(e => *e.event_package).canFind(*event.event_package)) {
                                not_the_same ~= event;
                            }
                        }
                        foreach (event; to_compare) {
                            if (!node_events.map!(e => *e.event_package).canFind(*event.event_package)) {
                                not_the_same ~= event;
                                //do some callback
                            }
                        }
                    }
                }

                // check all events are the same
                auto epoch_events = epoch.value.byValue.map!(finished_epoch => finished_epoch.event_packages).array;
                string print_events() {
                    string printout;
                    // printout ~= format("EPOCH: %s", epoch.value.epoch);
                    foreach (i, events; epoch_events) {
                        uint number_of_empty_events;
                        printout ~= format("\n%s: ", i);
                        if (!continue_on_error)
                            foreach (j, epack; events) {
                                const go_hash = net.calcHash(*epack);
                                const equal = (j < epoch_events[0].length) && (net.calcHash(*epoch_events[0][j]) == go_hash);

                                const mark = (equal) ? GREEN : RED;
                                printout ~= format("%s%(%02x%):%03d ", mark, go_hash[0 .. 4], j);
                                if (epack.event_body.payload.empty) {
                                    number_of_empty_events++;
                                }
                            }
                        printout ~= format("TOTAL: %s EMPTY: %s", events.length, number_of_empty_events);
                    }
                    return printout;
                }

                if (!epoch_events.all!(e => equal(e.map!(e => *e), epoch_events[0].map!(e => *e)))) {
                    check(continue_on_error, format("not all events the same on epoch %s \n%s", epoch.key, print_events));
                    if (continue_on_error) {
                        writefln("%sMismatch Round %04d\n%s%s", RED, epoch.key, print_events, RESET);
                    }
                }

                auto timestamps = epoch.value.byValue.map!(finished_epoch => finished_epoch.time).array;
                if (!timestamps.all!(t => t == timestamps[0])) {
                    string text;
                    foreach (i, t; timestamps) {
                        auto line = format("\n%s: %s", i, t);
                        text ~= line;
                    }
                    check(continue_on_error, format("not all timestamps were the same!\n%s\n%s", text, print_events));
                }

                writefln("FINISHED ENTIRE EPOCH %s", epoch.key);
                last_epoch = max(last_epoch, epoch.key);
                epochs.remove(epoch.key);
            }
        }
    }
    catch (BehaviourException e) {
        throw e;
    }
}
