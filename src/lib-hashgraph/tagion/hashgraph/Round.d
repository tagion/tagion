/// HashGraph Event
module tagion.hashgraph.Round;

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
import tagion.basic.Types : Buffer;
import tagion.basic.basic : EnumText, basename, buf_idup, this_dot;
import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic : EvaPayload, EventBody, EventPackage, Tides, higher, isAllVotes, isMajority;
import tagion.monitor.Monitor : EventMonitorCallbacks;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord;
import tagion.logger.Logger;
import tagion.utils.BitMask : BitMask;
import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;
import tagion.basic.Debug;

/// Handles the round information for the events in the Hashgraph
@safe
class Round {
    //    bool erased;
    enum uint total_limit = 3;
    enum int coin_round_limit = 10;
    protected {
        Round _previous;
        Round _next;
        //bool _decided;
    }
    immutable int number;

    Event[] _events;
    //package Event[] _events;
    public BitMask famous_mask;
    BitMask seen_by_famous_mask;

    /**
 * Compare the round number 
 * Params:
 *   rhs = round to be checked
 * Returns: true if equal or less than
 */
    @nogc bool lessOrEqual(const Round rhs) pure const nothrow {
        return (number - rhs.number) <= 0;
    }

    /**
     * Construct a round from the previous round
     * Params:
     *   previous = previous round
     *   node_size = size of events in a round
     */
    private this(Round previous, const size_t node_size) pure nothrow {
        if (previous) {
            number = previous.number + 1;
            previous._next = this;
            _previous = previous;
        }
        else {
            number = 0;
        }
        _events = new Event[node_size];
    }

    /**
     * All the events in the first ooccurrences of this round
     * Returns: all events in a round
     */
    const(Event[]) events() const pure nothrow @nogc {
        return _events;
    }

    /**
     * Adds the even to round
     * Params:
     *   event = the event to be added
     */
    package void add(Event event) pure nothrow
    in {
        assert(event._witness, "The event id " ~ event.id.to!string ~ " added to the round should be a witness ");
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
    @nogc
    final bool empty() const pure nothrow {
        return !_events.any!((e) => e !is null);
    }

    /**
     * Counts the number of events which has been set in this round
     * Returns: number of events set
     */
    @nogc
    final size_t event_count() const pure nothrow {
        return _events.count!((e) => e !is null);
    }

    /**
     * Remove the event from the round 
     * Params:
     *   event = event to be removed
     */
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
    private void scrap(HashGraph hashgraph) @trusted
    in {
        assert(!_previous, "Round can not be scrapped due that a previous round still exists");
    }
    do {
        uint count;
        void scrap_events(Event e) {
            if (e !is null) {
                count++;

                pragma(msg, "fixme(phr): make event remove work with eventview");
                version (none)
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
    version (none) bool decided() const pure nothrow @nogc {
        return _decided;
    }

    /**
     * Previous round from this round
     * Returns: previous round
     */
    @nogc
    package Round previous() pure nothrow {
        return _previous;
    }

    @nogc
    const(Round) previous() const pure nothrow {
        return _previous;
    }

    const(Round) next() const pure nothrow @nogc {
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
    const(Event) event(const size_t node_id) const pure nothrow {
        return _events[node_id];
    }

    bool isFamous() const pure nothrow @nogc {
        return isMajority(_events
                .filter!(e => e !is null)
                .filter!(e => e.witness.votedYes)
                .count,
                _events.length);

    }

    bool majority() const pure nothrow @nogc {
        return isMajority(_events
                .filter!(e => e !is null)
                .count,
                _events.length);
    }

    uint decisions() const pure nothrow @nogc {
        return cast(uint) _events
            .filter!(e => e !is null)
            .map!(e => e.witness)
            .filter!(w => w.decided)
            .count;
    }

    uint famous() const pure nothrow @nogc {
        return cast(uint) _events
            .filter!(e => e !is null)
            .filter!(e => e.witness.votedYes)
            .count;
    }

    uint voters() const pure nothrow @nogc {
        return cast(uint)(_events.filter!(e => e !is null).count);
    }

    uint count_feature_famous_rounds() const pure nothrow {
        return cast(uint) this[]
            .retro
            .until!(r => !isMajority(r.voters, _events.length))
            .filter!(r => r.isFamous)
            .count;
    }

    invariant {
        assert(!_previous || (_previous.number + 1 is number));
        assert(!_next || (_next.number - 1 is number));
    }

    /**
 * Range from this round and down
 * Returns: range of rounds 
 */
    @nogc
    package Rounder.Range!false opSlice() pure nothrow {
        return Rounder.Range!false(this);
    }

    /// Ditto
    @nogc
    Rounder.Range!true opSlice() const pure nothrow {
        return Rounder.Range!true(this);
    }

    /**
     * The rounder takes care of cleaning up old round 
     * and keeps track of if an round has been decided or can be decided
     */
    struct Rounder {
        Round last_round;
        Round last_decided_round;
        HashGraph hashgraph;
        Event[] last_witness_events;
        //Round[] voting_round_per_node;
        @disable this();

        this(HashGraph hashgraph) pure nothrow {
            this.hashgraph = hashgraph;
            last_round = new Round(null, hashgraph.node_size);
            last_witness_events.length = hashgraph.node_size;
            //voting_round_per_node = last_round.repeat(hashgraph.node_size).array;
        }

        package void erase() {
            void local_erase(Round r) @trusted {
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

        /**
     * Sets the round for an event and creates an new round if needed
     * Params:
     *   e = event
     */
        void set_round(Event e) nothrow
        in {
            assert(!e._round, "Round has allready been added");
            assert(last_round, "Base round must be created");
            assert(last_decided_round, "Last decided round must exist");
            assert(e, "Event must create before a round can be added");
        }
        do {
            scope (exit) {
                if (e._witness) {
                    e._round.add(e);
                    last_witness_events[e.node_id] = e;
                }
            }
            e._round = e.maxRound;
            if (e._witness && e._round._events[e.node_id]) {
                if (e._round._next) {

                    e._round = e._round._next;
                    return;
                }
                e._round = new Round(last_round, hashgraph.node_size);
                last_round = e._round;
            }
        }

        //Cleans up old round and events if they are no-longer needed

        package
        void dustman() {
            void local_dustman(Round r) {
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
                for (Round r = last_decided_round; r !is null; r = r._previous) {
                    depth--;
                    if (depth < 0) {
                        local_dustman(r);
                        break;
                    }
                }
            }
        }

        @nogc final const pure nothrow {
            /**
  * Number of round epoch in the rounder queue
  * Returns: size of the queue
   */
            size_t length() {
                return this[].walkLength;
            }

            bool isEventInLastDecidedRound(const(Event) event) {
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
            bool decided(const Round r) {
                if (r) {
                    return (r.number - last_decided_round.number) <= 0;
                }
                return false;
            }

            /**
     * Calculates the number of rounds since the last decided round
     * Returns: number of undecided roundes 
     */
            long coin_round_distance() {
                return last_round.number - last_decided_round.number;
            }

            /**
     * Number of decided round in cached in memory
     * Returns: Number of cached decided rounds
     */
            uint cached_decided_count() {
                uint _cached_decided_count(const Round r, const uint i = 0) pure nothrow {
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
            bool check_decided_round_limit() {
                return cached_decided_count > total_limit;
            }

            bool can_round_be_decided(const Round r) {
                bool _decided(T)(const T item) @nogc {
                    if (item.value) {
                        return item.value.witness.decided;
                    }
                    const last_witness_event = last_witness_events[item.index];
                    if (last_witness_event) {
                        return last_witness_event._round.number > r.number;
                    }
                    return (last_round.number - r.number) >= hashgraph.last_witness_height_limit;
                }

                if (r) {
                    auto witness_in_round = r._events.filter!(e => e !is null);
                    if (isMajority(witness_in_round.count, hashgraph.node_size)) {
                        return r._events.enumerate
                            .all!(item => _decided(item));
                    }
                }
                return false;
            }
        }
        static size_t number_of_witness(const Round r) pure nothrow @nogc {
            if (r) {
                return r._events.filter!(e => e !is null).count;
            }
            return 0;
        }

        void check_decide_round() {
            auto round_to_be_decided = last_decided_round._next;
            if (!round_to_be_decided) {
                return;
            }
            auto witness_in_round = round_to_be_decided._events
                .filter!(e => e !is null)
                .map!(e => e.witness);
            if (!isMajority(witness_in_round.count, hashgraph.node_size)) {
                return;
            }
            version (none)
                witness_in_round
                    .filter!(w => !w.decided)
                    .each!(w => w.doTheMissingNoVotes);
            if (isMajority(witness_in_round.count, hashgraph.node_size)) {
                __write("%s voters=%d Round=%d %(%s %) yes=%d no=%d decided=%d",
                        hashgraph.name,
                        (round_to_be_decided._next) ? round_to_be_decided._next._events.filter!(e => e !is null).count
                        : 0,
                        round_to_be_decided.number,
                        witness_in_round
                            .filter!(w => !w.decided)
                            .map!(w => only(w.yes_votes, w.no_votes, w.decided,
                                (last_witness_events[w.outer.node_id]!is null) ? last_witness_events[w.outer.node_id]
                    .round
                    .number : -1
                )),
                witness_in_round.filter!(w => w.votedYes).count,
                witness_in_round.filter!(w => w.votedNo)
                    .count,
                    witness_in_round.filter!(w => w.decided).count);
                __write("%s round=%d next_votes=%s famous=%d:%d", hashgraph.name, round_to_be_decided.number,
                        round_to_be_decided[].retro
                        .until!(r => !isMajority(r.decisions, hashgraph.node_size))
                        .map!(r => only(r.voters, r.decisions, r.famous)),
                        round_to_be_decided[].retro.filter!(r => isMajority(r.famous, hashgraph.node_size)).count,
                        round_to_be_decided.count_feature_famous_rounds);

            }
            //const threshold_or_none_decided = (witness_in_round.all!(w => w.decided)) ? 3 : 7;
            const threshold_or_none_decided = 7; // (can_round_be_decided(round_to_be_decided)) ? 3 : 7;
            if (!can_round_be_decided(round_to_be_decided) && round_to_be_decided.count_feature_famous_rounds < threshold_or_none_decided) {

                //version (none) {
                //                    round_to_be_decided = find_next_famous_round(round_to_be_decided);
                //                    if (round_to_be_decided) {
                //                        if (can_round_be_decided(round_to_be_decided._next, 4)) {
                //                            check_decide_round(round_to_be_decided);
                //                        }
                // }
                //}
                log("Not decided round");
                return;

            }
            witness_in_round //.filter!(w => !isMajority(w.yes_votes, hashgraph.node_size))
                .each!(w => Event.callbacks.connect(w.outer));
            //witness_in_round.each!(w => w.display_decided);
            version (none)
                __write("decided %s", witness_in_round.map!(w => w.decided));
            //witness_in_round.each!(w => w.display_decided);
            //round_to_be_decided._decided = true;
            __write("Round decided %d count=%d", round_to_be_decided.number, witness_in_round.count);
            last_decided_round = round_to_be_decided;
            version (none)
                __write("round %d votes yes %(%s %)", round_to_be_decided.number,
                        witness_in_round.map!(w => isMajority(w.yes_votes, hashgraph.node_size)));
            version (none) const decided_with_yes_votes = witness_in_round
                .filter!(w => w.votedYes)
                .count;
            version (none)
                __write("decided_with_yes_votes=%d %s", decided_with_yes_votes, isMajority(decided_with_yes_votes, hashgraph
                        .node_size));
            //if (!isMajority(decided_with_yes_votes, hashgraph.node_size)) {
            if (!round_to_be_decided.isFamous) {
                return;
            }
            collect_received_round(round_to_be_decided);
            check_decide_round;
        }

        protected void collect_received_round(Round r)
        in (decided(r), "The round should be decided before the round can be collect")
        do {

            auto witness_event_in_round = r._events.filter!(e => e !is null);
            const famous_count = witness_event_in_round
                .map!(e => e.witness)
                .map!(w => w.votedYes)
                .count;
            if (!isMajority(famous_count, hashgraph.node_size)) {
                // The number of famous is not in majority 
                // This means that we have to wait for the next round
                // to collect the events
                return;
            }
            Event[] majority_seen_from_famous(R)(R famous_witness_in_round) @safe if (isInputRange!R) {
                Event[] event_list;
                event_list.length = hashgraph.node_size * hashgraph.node_size;
                uint index;
                foreach (famous_witness; famous_witness_in_round) {
                    BitMask father_mask;
                    foreach (e; famous_witness[].until!(e => !e || e.round_received)) {
                        if (e._father && !father_mask[e._father.node_id]) {
                            father_mask[e._father.node_id] = true;
                            event_list[index++] = e;
                        }
                    }
                }
                event_list.length = index;
                return event_list;
            }

            auto famous_witness_in_round = witness_event_in_round
                .filter!(e => e._witness.isFamous);
            auto event_list = majority_seen_from_famous(famous_witness_in_round);
            event_list
                .sort!((a, b) => Event.higher_order(a, b));
            BitMask[] famous_seen_masks;
            famous_seen_masks.length = hashgraph.node_size;

            Event[] event_front;
            event_front.length = hashgraph.node_size;
            const mask_fmt = "%" ~ hashgraph.node_size.to!string ~ "s";
            foreach (e; event_list) {
                famous_seen_masks[e.node_id][e.node_id] = true;
                famous_seen_masks[e._father.node_id] |= famous_seen_masks[e.node_id];
                const top = isMajority(famous_seen_masks[e._father.node_id], hashgraph);
                version (none)
                    __write("father_id=%d node_id=%d -> father_node_id=%d order=%d:%d " ~ mask_fmt ~ " %s",
                            e._father.id, e.node_id, e._father.node_id,
                            e.order, e._father.order, famous_seen_masks[e._father.node_id],
                            (top) ? format("TOP %d", famous_seen_masks[e._father.node_id].count) : ""
                );
                if (!event_front[e._father.node_id] && isMajority(famous_seen_masks[e._father.node_id], hashgraph)) {
                    event_front[e._father.node_id] = e._father;
                }
            }
            __write("Top selection round %d witness_in_round=%d", r.number, witness_event_in_round.walkLength);
            version (none)
                event_front
                    .filter!(e => e !is null)
                    .each!(e => __write("round=%d id=%d son_node_id=%d -> node_id=%d order=%d", e.round.number, e.id, e
                            .son
                            .node_id, e.node_id, e
                            .order));
            bool done;
            do {
                done = true;
                foreach (e; event_front.filter!(e => e !is null)) {
                    foreach (e_father; e[]
                        .until!(e => !e || e.round_received)
                        .filter!(e => e._father)
                        .map!(e => e._father)
                        .filter!(e_father => !event_front[e_father.node_id] ||
                        e_father.order > event_front[e_father.node_id].order)
                    ) {
                        done = false;
                        event_front[e_father.node_id] = e_father;
                    }
                }
            }
            while (!done);

            event_front
                .filter!(e => e !is null)
                .each!(e => e.top = true);

            event_front
                .filter!(e => e !is null)
                .each!(e => Event.callbacks.connect(e));
            version (none) {
                auto order_list = event_front.filter!(e => e !is null)
                    .map!(e => e.order)
                    .array
                    .sort;
                __write("order_list=%s", order_list);
            }
            auto event_collection = event_front
                .filter!(e => e !is null)
                .map!(e => e[]
                .until!(e => e.round_received !is null))
                .joiner
                .array;
            event_collection.each!(e => e.round_received = r);
            if (Event.callbacks) {
                event_collection.each!(e => Event.callbacks.connect(e));
            }
            __write("EPOCH Round collected %d event_collection=%d", r.number, event_collection.length);
            hashgraph.epoch(event_collection, r);

        }

        /**
     * Call to collect and order the epoch
     * Params:
     *   r = decided round to collect events to produce the epoch
     *   hashgraph = hashgraph which owns this round
     */

        /**
         * Range from this round and down
         * Returns: range of rounds 
         */
        @nogc
        package Range!false opSlice() pure nothrow {
            return Range!false(last_round);
        }

        /// Ditto
        @nogc
        Range!true opSlice() const pure nothrow {
            return Range!true(last_round);
        }

        /**
     * Range of rounds 
     */
        @nogc
        struct Range(bool CONST = true) {
            private Round round;
            this(const Round round) pure nothrow @trusted {
                this.round = cast(Round) round;
            }

            pure nothrow {
                static if (CONST) {
                    const(Round) front() const {
                        return round;
                    }
                }
                else {
                    Round front() {
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

        static assert(isInputRange!(Range!true));
        static assert(isForwardRange!(Range!true));
        static assert(isBidirectionalRange!(Range!true));
    }

}
