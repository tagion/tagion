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
        //        BitMask _voter_exists_mask; /// Marks if a voter exists
    }
    immutable int number;

    Event[] _events;
    protected bool _decided;
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

    final uint node_size() const pure nothrow @nogc {
        return cast(uint) _events.length;
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
     * Previous round from this round
     * Returns: previous round
     */
    @nogc
    package Round previous() pure nothrow {
        return _previous;
    }

    final const pure nothrow @nogc {
        /**
     * Check of the round has no events
     * Returns: true of the round is empty
     */
        bool empty() {
            return !_events.any!((e) => e !is null);
        }

        /**
     * Counts the number of events which has been set in this round
     * Returns: number of events set
     */
        size_t event_count() {
            return _events.count!((e) => e !is null);
        }

        const(Round) previous() {
            return _previous;
        }

        const(Round) next() {
            return _next;
        }

        /**
     * Get the event a the node_id 
     * Params:
     *   node_id = node id number
     * Returns: 
     *   Event at the node_id
     */
        const(Event) event(const size_t node_id) {
            return _events[node_id];
        }

        bool isFamous() {
            return isMajority(_events
                    .filter!(e => e !is null)
                    .filter!(e => e.witness.votedYes)
                    .count,
                    _events.length);

        }

        bool majority() {
            return isMajority(_events
                    .filter!(e => e !is null)
                    .count,
                    _events.length);
        }

        uint decisions() {
            return cast(uint) _events
                .filter!(e => e !is null)
                .map!(e => e.witness)
                .filter!(w => w.decided)
                .count;
        }

        uint famous() {
            return cast(uint) _events
                .filter!(e => e !is null)
                .filter!(e => e.witness.votedYes)
                .count;
        }

        uint voters() {
            return cast(uint)(_events.filter!(e => e !is null).count);
        }
    }
    final uint count_feature_famous_rounds() const pure nothrow {
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

    final void decide() pure nothrow @nogc
    in (!_decided)
    do {
        _decided = true;
    }

    final bool decided() const pure nothrow @nogc {
        return _decided;
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

        }
        final bool can_round_be_decided(const Round r) const pure nothrow {
            bool _decided(T)(const T item) @nogc {
                if (item.value && item.value.witness.decided) {
                    return true;
                }
                const last_witness_event = last_witness_events[item.index];
                if (last_witness_event &&
                        (last_witness_event._round.number - r.number) > 0) {
                    return true;
                }
                return false;
                //return (last_round.number - r.number) >= hashgraph.last_witness_height_limit;
            }

            if (r) {
                const decided_votes = r._events
                    .enumerate
                    .filter!(item => _decided(item))
                    .count;
                if (decided_votes == r.node_size) {
                    return true;
                }
                if (isMajority(decided_votes, r.node_size)) {
                    //const last_round_beond=(last_round.number-r.number) > 2;
                    const number_of_sealed_witness = r.node_size
                        .iota
                        .map!(w_node_id => last_witness_events[w_node_id])
                        .filter!(e => (e) ? (e.round.number - r.number) > 0 : (last_round.number - r.number) > 2)
                        .count;
                    if (number_of_sealed_witness == r.node_size) {
                        return true;
                    }
                }

            }
            return false;
        }

        version (none) private void update_ballot_list(Round r) pure nothrow {
            bool voter_exists(const size_t node_id) pure nothrow {
                if (last_witness_events[node_id]) {
                    return !r.events[node_id] &&
                        (last_witness_events[node_id].round.number - r.events[node_id].round.number) > 0;
                }
                return false;
            }

            r._voter_exists_mask |= BitMask(
                    r._voter_exists_mask.invert(r.events.length)[]
                    .filter!(voting_node_id => voter_exists(voting_node_id)));
        }

        void check_decide_round() {
            auto round_to_be_decided = last_decided_round._next;
            if (!round_to_be_decided) {
                return;
            }
            //version(none) 
            auto witness_in_round = round_to_be_decided._events
                .filter!(e => e !is null)
                .map!(e => e.witness);
            version (none)
                if (!isMajority(witness_in_round.count, hashgraph.node_size)) {
                    return;
                }
            //update_ballot_list(round_to_be_decided);
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
                __write("%s round=%d next_votes=%s famous=%d", hashgraph.name, round_to_be_decided.number,
                        round_to_be_decided[].retro
                        .until!(r => !isMajority(r.decisions, hashgraph.node_size))
                        .map!(r => only(r.voters, r.decisions, r.famous)),//round_to_be_decided[].retro.filter!(r => isMajority(r.famous, hashgraph.node_size)).count,
                        round_to_be_decided.count_feature_famous_rounds);

                //__write("voter_exists=%5s", round_to_be_decided._voter_exists_mask);
            }
            if (!can_round_be_decided(round_to_be_decided)) {
                return;

            }
            Event.view(witness_in_round.map!(w => w.outer));

            if (!witness_in_round.map!(w => w.votedYes).all) {
                return;
            }
            __write("Round decided %d count=%d", round_to_be_decided.number, witness_in_round.count);
            log("Round %d decided", round_to_be_decided.number);
            round_to_be_decided.decide;
            last_decided_round = round_to_be_decided;
            __write("Collect %d decided=%d witness=%d next_witness=%d",
                    round_to_be_decided.number,
                    round_to_be_decided.events
                    .filter!(e => e !is null)
                    .filter!(e => e.witness.votedYes)
                    .count,
                    round_to_be_decided.events.filter!(e => e !is null).count,
                    round_to_be_decided.next.events.filter!(e => e !is null).count
            );
            collect_received_round(round_to_be_decided);
            log("Round %d collected", round_to_be_decided.number);
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
            foreach (e; event_list) {
                famous_seen_masks[e.node_id][e.node_id] = true;
                famous_seen_masks[e._father.node_id] |= famous_seen_masks[e.node_id];
                const top = isMajority(famous_seen_masks[e._father.node_id], hashgraph);
                if (!event_front[e._father.node_id] && isMajority(famous_seen_masks[e._father.node_id], hashgraph)) {
                    event_front[e._father.node_id] = e._father;
                }
            }
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

            auto event_collection = event_front
                .filter!(e => e !is null)
                .map!(e => e[]
                .until!(e => e.round_received !is null))
                .joiner
                .array;
            event_collection.each!(e => e.round_received = r);
            Event.view(event_collection);
            __write("EPOCH Round collected %d event_collection=%d", r.number, event_collection.length);
            hashgraph.epoch_events_statistic(event_collection.length);
            log.event(Event.topic, hashgraph.epoch_events_statistic.stringof, hashgraph.epoch_events_statistic);
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
