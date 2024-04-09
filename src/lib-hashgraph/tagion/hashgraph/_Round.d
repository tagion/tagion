/// HashGraph Event
module tagion.hashgraph._Round;

//import std.stdio;

import std.datetime; // Date, DateTime
import std.algorithm.iteration : cache, each, filter, fold, joiner, map, reduce;
import std.algorithm.searching;
import std.algorithm.searching : all, any, canFind, count, until;
import std.algorithm.sorting : sort;
import std.array : array;
import std.conv;
import std.format;
import std.range;
import std.range : enumerate, tee;
import std.range.primitives : isBidirectionalRange, isForwardRange, isInputRange, walkLength;
import std.stdio;
import std.traits : ReturnType, Unqual;
import std.traits;
import std.typecons;
import std.typecons : No;
import tagion.basic.Debug;
import tagion.basic.Types : Buffer;
import tagion.basic.basic : EnumText, basename, buf_idup, this_dot;
import tagion.crypto.Types : Pubkey;
import tagion.hashgraph._Event;
import tagion.hashgraph._HashGraph : _HashGraph;
import tagion.hashgraph.HashGraphBasic : EvaPayload, EventBody, EventPackage, Tides, higher, isAllVotes, isMajority;
import tagion.monitor.Monitor : EventMonitorCallbacks;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord;
import tagion.logger.Logger;
import tagion.utils.BitMask : BitMask;
import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;
import current_round=tagion.hashgraph.Round;
import current_event=tagion.hashgraph.Event;

/// Handles the round information for the events in the Hashgraph
@safe
class _Round : current_round.Round {
    //    bool erased;
    //enum uint total_limit = 3;
    //enum int coin_round_limit = 10;
    version(none)
    protected {
        _Round _previous;
        _Round _next;
        bool _decided;
    }
    //immutable long number;

    //package Event[] _events;
    //public BitMask famous_mask;

    /**
 * Compare the round number 
 * Params:
 *   rhs = round to be checked
 * Returns: true if equal or less than
 */
    version(none)
    @nogc bool lessOrEqual(const _Round rhs) pure const nothrow {
        return (number - rhs.number) <= 0;
    }

    /**
     * Number of events in a round should be the same 
     * as the number of nodes in the hashgraph
     * Returns: number of nodes in the round 
     */
    version(none)
    @nogc const(uint) node_size() pure const nothrow {
        return cast(uint) _events.length;
    }

    /**
     * Construct a round from the previous round
     * Params:
     *   previous = previous round
     *   node_size = size of events in a round
     */
    private this(_Round previous, const size_t node_size) pure nothrow {
        if (previous) {
            number = previous.number + 1;
            previous._next = this;
            _previous = previous;
        }
        else {
            number = 0;
        }
        _events = new _Event[node_size];
    }

    /**
     * All the events in the first ooccurrences of this round
     * Returns: all events in a round
     */
    version(none)
    @nogc
    const(Event[]) events() const pure nothrow {
        return _events;
    }

    /**
     * Adds the even to round
     * Params:
     *   event = the event to be added
     */
    version(none)
    package void add(Event event) pure nothrow
    in {
        assert(_events[event.node_id] is null, "Event at node_id " ~ event.node_id.to!string ~ " should only be added once");
    }
    do {
        _events[event.node_id] = event;
        event._round = this;
    }

    /**
     * Check of the round has no events
     * Returns: true of the round is empty
     */
    version(none)
    @nogc
    bool empty() const pure nothrow {
        return !_events.any!((e) => e !is null);
    }

    /**
     * Counts the number of events which has been set in this round
     * Returns: number of events set
     */
    version(none)
    @nogc
    size_t event_count() const pure nothrow {
        return _events.count!((e) => e !is null);
    }

    /**
     * Remove the event from the round 
     * Params:
     *   event = event to be removed
     */
   version(none)
    @nogc
    package void remove(const(Event) event) nothrow
    in {
        assert(event.isEva || _events[event.node_id] is event,
                "This event does not exist in round at the current node so it can not be remove from this round");
        assert(event.isEva || !empty, "No events exists in this round");
    }
    do {
        if (!event.isEva && _events[event.node_id]) {
            _events[event.node_id] = null;
        }
    }

    /**
     * Scrap all rounds and events from this round and downwards 
     * Params:
     *   hashgraph = the hashgraph owning the events/rounds
     */
    version(none)
    private void scrap(HashGraph hashgraph) @trusted
    in {
        assert(!_previous, "_Round can not be scrapped due that a previous round still exists");
    }
    do {
        uint count;
        void scrap_events(Event e) {
            if (e !is null) {
                count++;

                pragma(msg, "fixme(phr): make event remove work with eventview");
                version(none)
                if (Event.callbacks) {
                    Event.callbacks.remove(e);
                }
                scrap_events(e._mother);
                e.disconnect(hashgraph);
                e.destroy;
            }
        }

        foreach (node_id, e; _events) {
            scrap_events(e);
        }
        if (_next) {
            _next._previous = null;
            _next = null;
        }
    }

    /**
     * Check if the round has been decided
     * Returns: true if the round has been decided
     */
    version(none)
    @nogc bool decided() const pure nothrow {
        return _decided;
    }

    override const(_Round) next() const pure nothrow {
        return _next;
    }

    /**
     * Get the event a the node_id 
     * Params:
     *   node_id = node id number
     * Returns: 
     *   Event at the node_id
     */
    @nogc
    override inout(current_event.Event) event(const size_t node_id) pure inout {
        return _events[node_id];
    }

    /**
     * Previous round from this round
     * Returns: previous round
     */
    version(none)
    @nogc
    package _Round previous() pure nothrow {
        return _previous;
    }

    @nogc
    override const(_Round) previous() const pure nothrow {
        return _previous;
    }

    /**
 * Range from this round and down
 * Returns: range of rounds 
 */
    version(none)
    @nogc
    package Rounder.Range!false opSlice() pure nothrow {
        return Rounder.Range!false(this);
    }

    /// Ditto
    version(none)
    @nogc
    Rounder.Range!true opSlice() const pure nothrow {
        return Rounder.Range!true(this);
    }

    invariant {
        assert(!_previous || (_previous.number + 1 is number));
        assert(!_next || (_next.number - 1 is number));
    }

    /**
     * The rounder takes care of cleaning up old round 
     * and keeps track of if an round has been decided or can be decided
     */
    struct Rounder {
        _Round last_round;
        _Round last_decided_round;
        _HashGraph hashgraph;
        _Round[] voting_round_per_node;

        @disable this();

        this(_HashGraph hashgraph) pure nothrow {
            this.hashgraph = hashgraph;
            last_round = new _Round(null, hashgraph.node_size); 
            voting_round_per_node = last_round.repeat(hashgraph.node_size).array;
        }

        package void erase() {
            void local_erase(_Round r) @trusted {
                if (r !is null) {
                    local_erase(r._previous);
                    r.scrap(hashgraph);
                    r.destroy;
                }
            }

            Event.scrapping = true;
            scope (exit) {
                Event.scrapping = false;
            }
            last_decided_round = null;
            local_erase(last_round);
        }

        //Cleans up old round and events if they are no-longer needed

        package
        void dustman() {
            void local_dustman(_Round r) {
                if (r !is null) {
                    local_dustman(r._previous);
                    r.scrap(hashgraph);
                }
            }

            Event.scrapping = true;
            scope (exit) {
                Event.scrapping = false;
            }
            if (hashgraph.scrap_depth != 0) {
                int depth = hashgraph.scrap_depth;
                for (_Round r = last_decided_round; r !is null; r = r._previous) {
                    depth--;
                    if (depth < 0) {
                        local_dustman(r);
                        break;
                    }
                }
            }
        }

        /**
  * Number of round epoch in the rounder queue
  * Returns: size of the queue
   */
        @nogc
        size_t length() const pure nothrow {
            return this[].walkLength;
        }

        /**
     * Number of the same as hashgraph
     * Returns: number of nodes
     */
        uint node_size() const pure nothrow
        in {
            assert(last_round, "Last round must be initialized before this function is called");
        }
        do {
            return cast(uint)(last_round._events.length);

        }

        /**
     * Sets the round for an event and creates an new round if needed
     * Params:
     *   e = event
     */
        void next_round(_Event e) nothrow
        in {
            assert(last_round, "Base round must be created");
            assert(last_decided_round, "Last decided round must exist");
            assert(e, "Event must create before a round can be added");
        }
        out {
            assert(e._round !is null);
        }
        do {
            scope (exit) {
                e._round.add(e);
            }
            if (e._round && e._round._next) {
                e._round = e._round._next;
            }
            else {
                e._round = new _Round(last_round, hashgraph.node_size);
                last_round = e._round;
                // if (Event.callbacks) {
                //     Event.callbacks.round_seen(e);
                // }
            }
        }

         bool isEventInLastDecidedRound(const(_Event) event) const pure nothrow @nogc {
            if (!last_decided_round) {
                return false;
            }

            return last_decided_round.events
                .filter!((e) => e !is null)
                .map!(e => e.event_package.fingerprint)
                .canFind(event.event_package.fingerprint);
        }

        /**
     * Check of a round has been decided
     * Params:
     *   test_round = round to be tested
     * Returns: 
     */
        @nogc
        bool decided(const _Round test_round) pure const nothrow {

            bool _decided(const _Round r) pure nothrow {
                if (r) {
                    if (test_round is r) {
                        return true;
                    }
                    return _decided(r._next);
                }
                return false;
            }

            return _decided(last_decided_round);
        }

        /**
     * Calculates the number of rounds since the last decided round
     * Returns: number of undecided roundes 
     */
        @nogc
        long coin_round_distance() pure const nothrow {
            return last_round.number - last_decided_round.number;
        }

        /**
     * Number of decided round in cached in memory
     * Returns: Number of cached decided rounds
     */
        @nogc
        uint cached_decided_count() pure const nothrow {
            uint _cached_decided_count(const _Round r, const uint i = 0) pure nothrow {
                if (r) {
                    return _cached_decided_count(r._previous, i + 1);
                }
                return i;
            }

            return _cached_decided_count(last_round);
        }

        /**
     * Check the coin round limit
     * Returns: true if the coin round has been exceeded 
     */
        @nogc
         bool check_decided_round_limit() pure const nothrow {
            return cached_decided_count > total_limit;
        }

         void check_decide_round() {
            auto round_to_be_decided = last_decided_round._next;
            if (!voting_round_per_node.all!(r => r.number > round_to_be_decided.number)) {
                log("Not decided round");
                return;
            }
            collect_received_round(round_to_be_decided, hashgraph);
            round_to_be_decided._decided = true;
            last_decided_round = round_to_be_decided;
        }

    /**
     * Call to collect and order the epoch
     * Params:
     *   r = decided round to collect events to produce the epoch
     *   hashgraph = hashgraph which owns this round
     */

        package  void collect_received_round(_Round r, _HashGraph hashgraph) {

            auto famous_witnesses = r._events.filter!(e => e && r.famous_mask[e.node_id]);

            pragma(msg, "fixme(bbh) potential fault at boot of network if youngest_son_ancestor[x] = null");
            auto famous_witness_youngest_son_ancestors = famous_witnesses.map!(e => e._youngest_son_ancestors).joiner;

            Event[] consensus_son_tide = r._events.find!(e => e !is null).front._youngest_son_ancestors.dup();

            foreach (son_ancestor; famous_witness_youngest_son_ancestors.filter!(e => e !is null)) {
                if (consensus_son_tide[son_ancestor.node_id] is null) {
                    continue;
                }
                if (higher(consensus_son_tide[son_ancestor.node_id].order, son_ancestor.order)) {
                    consensus_son_tide[son_ancestor.node_id] = son_ancestor;
                }
            }

            version (EPOCH_FIX) {
                auto consensus_tide = consensus_son_tide
                    .filter!(e => e !is null)
                    .filter!(e =>
                            !(e[].retro
                                .until!(e => !famous_witnesses.all!(w => w.sees(e)))
                                .empty)
                )
                    .map!(e =>
                            e[].retro
                                .until!(e => !famous_witnesses.all!(w => w.sees(e)))
                                .array.back
                );
            }
            else {
                auto consensus_tide = consensus_son_tide
                    .filter!(e => e !is null)
                    .map!(e =>
                            e[].retro
                                .until!(e => !famous_witnesses.all!(w => w.sees(e)))
                                .array.back
                );

            }

            auto event_collection = consensus_tide
                .map!(e => e[].until!(e => e.round_received !is null))
                .joiner.array;

            event_collection.each!(e => e.round_received = r);
            if (Event.callbacks) {
                event_collection.each!(e => Event.callbacks.connect(e));
            }

            hashgraph.epoch(event_collection, r);
        }

        package void vote(_HashGraph hashgraph, size_t vote_node_id) {
            voting_round_per_node[vote_node_id] = voting_round_per_node[vote_node_id]._next;
            _Round current_round = voting_round_per_node[vote_node_id];
            if (voting_round_per_node.all!(r => !higher(current_round.number, r.number))) {
                check_decide_round();
            }

            while (current_round._next !is null) {
                current_round = current_round._next;
                foreach (e; current_round._events.filter!(e => e !is null)) {
                    e.calc_vote(hashgraph, vote_node_id);
                }
            }
        }

        /**
         * Range from this round and down
         * Returns: range of rounds 
         */
        version(none)
        @nogc
        package Range!false opSlice() pure nothrow {
            return Range!false(last_round);
        }

        /// Ditto
        version(noen)
        @nogc
        Range!true opSlice() const pure nothrow {
            return Range!true(last_round);
        }

        /**
     * Range of rounds 
     */
        version(none)
        @nogc
        struct Range(bool CONST = true) {
            private _Round round;
            this(const _Round round) pure nothrow @trusted {
                this.round = cast(_Round) round;
            }

            pure nothrow {
                static if (CONST) {
                    const(_Round) front() const {
                        return round;
                    }
                }
                else {
                    _Round front() {
                        return round;
                    }
                }

                alias back = front;

                bool empty() const {
                    return round is null;
                }

                void popBack() {
                    round = round._next;
                }

                void popFront() {
                    round = round._previous;
                }

                Range save() {
                    return Range(round);
                }

            }

        }
        version(none) {
        static assert(isInputRange!(Range!true));
        static assert(isForwardRange!(Range!true));
        static assert(isBidirectionalRange!(Range!true));
        }
    }

}
