/// HashGraph Event
module tagion.hashgraph.Event;

//import std.stdio;

import std.datetime; // Date, DateTime
import std.exception : assumeWontThrow;
import std.conv;
import std.range;
import std.format;
import std.typecons;
import std.traits : Unqual, ReturnType;
import std.array : array;

import std.algorithm.sorting : sort;
import std.algorithm.iteration : map, each, filter, cache, fold, joiner;
import std.algorithm.searching : count, any, all, until, canFind;
import std.range.primitives : walkLength, isInputRange, isForwardRange, isBidirectionalRange;
import std.range : enumerate, tee;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;

import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;

import tagion.basic.Types : Buffer;
import tagion.basic.basic : this_dot, basename, EnumText, buf_idup;
import tagion.crypto.Types : Pubkey;
import tagion.Keywords : Keywords;
import tagion.basic.Debug;

import tagion.logger.Logger;
import tagion.hashgraph.HashGraphBasic : isMajority, isAllVotes, higher, EventBody, EventPackage, EvaPayload, Tides;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraphview.EventMonitorCallbacks;
import tagion.utils.BitMask : BitMask;

import std.typecons : No;

import std.stdio;

/// Handles the round information for the events in the Hashgraph
@safe
class Round {
    //    bool erased;
    enum uint total_limit = 3;
    enum int coin_round_limit = 10;
    pragma(msg, "fixme(bbh) should be protected");
    protected {
        Round _previous;
        Round _next;
        bool _decided;
    }
    immutable int number;

    private Event[] _events;
    public BitMask famous_mask;

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
     * Number of events in a round should be the same 
     * as the number of nodes in the hashgraph
     * Returns: number of nodes in the round 
     */
    @nogc const(uint) node_size() pure const nothrow {
        return cast(uint) _events.length;
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
            number = -1;
        }
        _events = new Event[node_size];
    }

    /**
     * All the events in the first ooccurrences of this round
     * Returns: all events in a round
     */
    @nogc
    const(Event[]) events() const pure nothrow {
        return _events;
    }

    /**
     * Adds the even to round
     * Params:
     *   event = the event to be added
     */
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
    @nogc
    bool empty() const pure nothrow {
        return !_events.any!((e) => e !is null);
    }

    /**
     * Counts the number of events which has been set in this round
     * Returns: number of events set
     */
    @nogc
    size_t event_count() const pure nothrow {
        return _events.count!((e) => e !is null);
    }

    /**
     * Remove the event from the round 
     * Params:
     *   event = event to be removed
     */
    @nogc
    private void remove(const(Event) event) nothrow
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
    @trusted
    private void scrap(HashGraph hashgraph)
    in {
        assert(!_previous, "Round can not be scrapped due that a previous round still exists");
    }
    do {
        uint count;
        void scrap_events(Event e) {
            if (e !is null) {
                count++;
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
    @nogc bool decided() const pure nothrow {
        return _decided;
    }

    const(Round) next() const pure nothrow {
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
    inout(Event) event(const size_t node_id) pure inout {
        return _events[node_id];
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

    invariant {
        assert(!_previous || (_previous.number + 1 is number));
        assert(!_next || (_next.number - 1 is number));
    }

    /**
     * The rounder takes care of cleaning up old round 
     * and keeps track of if an round has been decided or can be decided
     */
    struct Rounder {
        Round last_round;
        Round last_decided_round;
        HashGraph hashgraph;
        Round[] voting_round_per_node;

        @disable this();

        this(HashGraph hashgraph) pure nothrow {
            this.hashgraph = hashgraph;
            last_round = new Round(null, hashgraph.node_size);

            voting_round_per_node = last_round.repeat(hashgraph.node_size).array;
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

        // package void set_lowest_undecided_witness(Event event) {
        //     voting_events[event.node_id] = &event;
        // }

        /**
     * Cleans up old round and events if they are no-longer needed
     */
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
        void next_round(Event e) nothrow
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
                e._round = new Round(last_round, hashgraph.node_size);
                last_round = e._round;
                // if (Event.callbacks) {
                //     Event.callbacks.round_seen(e);
                // }
            }
        }

        bool isEventInLastDecidedRound(const(Event) event) const pure nothrow @nogc {
            if (!last_decided_round) {
                return false;
            }

            return last_decided_round.events.filter!((e) => e !is null)
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
        bool decided(const Round test_round) pure const nothrow {
            bool _decided(const Round r) pure nothrow {
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
        int coin_round_distance() pure const nothrow {
            return last_round.number - last_decided_round.number;
        }

        /**
     * Number of decided round in cached in memory
     * Returns: Number of cached dicided rounds
     */
        @nogc
        uint cached_decided_count() pure const nothrow {
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
     * Returns: true if the coin round has beed exceeded 
     */
        @nogc
        bool check_decided_round_limit() pure const nothrow {
            return cached_decided_count > total_limit;
        }

        
    void decide_round() {
        auto round_to_be_decided = last_decided_round._next;
        if (!voting_round_per_node.all!(r => r.number > round_to_be_decided.number)) { return; }
        collect_received_round(round_to_be_decided, hashgraph);
        round_to_be_decided._decided = true;
        last_decided_round = round_to_be_decided;
            // if (hashgraph._rounds.voting_round_per_node.all!(r => r.number > round_to_be_decided.number)
            // {
            //     check_decided_round(hashgraph);        
            // } 
        }

        /**
     * Call to collect and order the epoch
     * Params:
     *   r = decided round to collect events to produce the epoch
     *   hashgraph = hashgraph which ownes this rounds
     */
        package void collect_received_round(Round r, HashGraph hashgraph) {
            uint mark_received_iteration_count;
            uint order_compare_iteration_count;
            uint rare_order_compare_count;
            uint epoch_events_count;
            // uint count;
            scope (success) {
                with (hashgraph) {
                    mark_received_statistic(mark_received_iteration_count);
                    mixin Log!(mark_received_statistic);
                    order_compare_statistic(order_compare_iteration_count);
                    mixin Log!(order_compare_statistic);
                    epoch_events_statistic(epoch_events_count);
                    mixin Log!(epoch_events_statistic);
                }
            }
            r._events
                .filter!((e) => (e !is null))
                .each!((e) => e[]
                .until!((e) => (e._round_received !is null))
                .each!((ref e) => e._round_received_mask.clear));

            void mark_received_events(const size_t voting_node_id, Event e) {
                mark_received_iteration_count++;
                if ((e) && (!e._round_received) && !e._round_received_mask[voting_node_id]) { // && !marker_mask[e.node_id] ) {
                    e._round_received_mask[voting_node_id] = true;
                    mark_received_events(voting_node_id, e._father);
                    mark_received_events(voting_node_id, e._mother);
                }
            }
            // Marks all the event below round r
            r._events
                .filter!((e) => (e !is null))
                .each!((ref e) => mark_received_events(e.node_id, e));

            // writefln("r._events=%s", r._events.count!((e) => e !is null && e.isFamous));
            auto event_collection = r._events
                .filter!((e) => (e !is null))
                .filter!((e) => !hashgraph.excluded_nodes_mask[e.node_id])
                .map!((ref e) => e[]
                .until!((e) => (e._round_received !is null))
                .filter!((e) => (e._round_received_mask.isMajority(hashgraph))))
                .joiner
                .tee!((e) => e._round_received = r)
                .array;

            // writefln("event_collection=%s", event_collection.count!((e) => e !is null && e.isFamous));
            hashgraph.epoch(event_collection, r);
        }

        /**
     * Called to check of the round can be decided
     * Params:
     *   hashgraph = hashgraph which owns the round 
     */

//         version(none)
//         void check_decided_round(HashGraph hashgraph) @trusted {
//             auto round_to_be_decided = last_decided_round._next;
//             void decide_round() {
//                 collect_received_round(round_to_be_decided, hashgraph);
// -                round_to_be_decided._decided = true;
// -                last_decided_round = round_to_be_decided;
// -                check_decided_round(hashgraph);
// -                return;
// -           }
// -
// -           if (hashgraph.possible_round_decided(round_to_be_decided))
//             {
// -                // writefln("possible_round_decided");
// -               const votes_mask = BitMask(round_to_be_decided.events
// -                        .filter!((e) => (e) && !hashgraph.excluded_nodes_mask[e.node_id])
// -                    .map!((e) => e.node_id));
// -               if (votes_mask.isMajority(hashgraph)) {
// -
// -                    if (Event.callbacks) {
// -                        votes_mask[].filter!(
// -                            (vote_node_id) => round_to_be_decided._events[vote_node_id].isFamous)
// -                            .each!((vote_node_id) => Event.callbacks.famous(
// -                                    round_to_be_decided._events[vote_node_id]));
// -                    }
// -
// -                    votes_mask[]
// -                        .each!((vote_node_id) => round_to_be_decided._events[vote_node_id]
// -                        ._witness.famous(hashgraph));
// -
// -                    const famous_round = votes_mask[]
// -                        .all!((vote_node_id) => round_to_be_decided._events[vote_node_id]
// -                        .isFamous);
// -
// -                    if (famous_round && votes_mask.count == hashgraph.node_size - hashgraph
// -                        .excluded_nodes_mask.count) {
// -                        decide_round();
// -                        return;
// -                    }
// -
// -                    uint count_rounds;
// -                    foreach (r; round_to_be_decided[].retro) {
// -                        const round_contains_witness = votes_mask[]
// -                            .all!(vote_node_id => r.events[vote_node_id]!is null);
// -
// -                        if (!round_contains_witness) {
// -                            break;
// -                        }
// -                        count_rounds++;
// -                        if (count_rounds > 6) {
// -                            decide_round();
// -                            return;
// -                        }
// -                    }
//                 }
//             }
//         }

        void vote(ulong vote_node_id, HashGraph hashgraph)
        {
            voting_round_per_node[vote_node_id] = voting_round_per_node[vote_node_id]._next;
            Round current_round = voting_round_per_node[vote_node_id];
            if (hashgraph._rounds.voting_round_per_node.all!(r => r.number >= current_round.number)) { hashgraph._rounds.decide_round(); }
            
            while(current_round._next !is null) {
                current_round = current_round._next;
                foreach (e; current_round._events) {
                    if (e is null) { continue; }
                    e.calc_vote(hashgraph, vote_node_id);
                }
            }
        }

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
            @trusted
            this(const Round round) pure nothrow {
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

/// HashGraph Event
@safe
class Event {
    package static bool scrapping;

    import tagion.basic.ConsensusExceptions;

    alias check = Check!EventConsensusException;
    protected static uint _count;

    package BitMask[] _witness_strong_seen_masks;
    package Event[] _youngest_ancestors;


    protected {
        // This is the internal pointer to the connected Event's
        Event _mother;
        Event _father;
        Event _daughter;
        Event _son;

        int _received_order;
        // The withness mask contains the mask of the nodes
        // Which can be seen by the next rounds witness
        Witness _witness;
        BitMask _round_seen_mask;
    }

    @nogc
    static uint count() nothrow {
        return _count;
    }

    bool error;

    /**
     * Builds an event from an eventpackage
     * Params:
     *   epack = event-package to build from
     *   hashgraph = the hashgraph which produce the event
     */
    package this(
        immutable(EventPackage)* epack,
        HashGraph hashgraph,
    )
    in (epack !is null)
    do {
        // _youngest_ancestors = new Event[hashgraph.node_size];
        _witness_strong_seen_masks = new BitMask[hashgraph.node_size];
        event_package = epack;
        this.id = hashgraph.next_event_id;
        this.node_id = hashgraph.getNode(channel).node_id;
        _count++;
    }

    protected ~this() {
        _count--;
    }

    invariant {
        if (!scrapping) {
            if (_mother) {
                // assert(!_witness_mask[].empty);
                assert(_mother._daughter is this);
                assert(
                    event_package.event_body.altitude - _mother
                        .event_package.event_body.altitude is 1);
                assert(_received_order is int.init || (_received_order - _mother._received_order > 0));
            }
            if (_father) {
                pragma(msg, "fixme(bbh) this test should be reimplemented once new witness def works");
                // assert(_father._son is this, "fathers is not me");
                assert(_received_order is int.init || (_received_order - _father._received_order > 0));
            }
        }
    }

    /**
     * The witness event will point to the witness object
     * This object contains infomation about the voting etc. for the witness event
     */
    @safe
    class Witness {
        protected static uint _count;
        @nogc static uint count() nothrow {
            return _count;
        }


        private {
            // immutable(BitMask) _seeing_witness_in_previous_round_mask; /// The mask resulting to this witness
            BitMask _strong_seeing_mask; /// Nodes which has voted this witness as strogly seen
            BitMask _vote_on_earliest_witnesses;
            BitMask _prev_strongly_seen_witnesses;
            BitMask _prev_seen_witnesses;
            Event[] _ancestors_tide;
            Event[] _descendants_tide;
            // Fame _famous; /// True if the witness is voted famous
        }


        /**
         * Contsruct a witness of an event
         * Params:
         *   owner_event = the event which is voted to be a witness
         *   seeing_witness_in_previous_round_mask = The witness seen from this event to the privious witness.
         */
        @trusted
        this(Event owner_event, ulong node_size) nothrow
        in {
            assert(owner_event);
        }
        do {

            this._ancestors_tide = new Event[node_size];
            this._descendants_tide = new Event[node_size];
            // _seeing_xhwitness_in_previous_round_mask = cast(immutable) seeing_witness_in_previous_round_mask
            //     .dup;
            _count++;
        }

        ~this() {
            _count--;
        }

        pure nothrow final {
            /**
 * Nodes which see this witness as strogly seen
 * Returns: strogly seening mask 
 */
            @nogc
            const(BitMask) strong_seeing_mask() const {
                return _strong_seeing_mask;
            }
        }
    }

    static EventMonitorCallbacks callbacks;

    // The altitude increases by one from mother to daughter
    immutable(EventPackage*) event_package;

    /**
  * The rounds see forward from this event
  * Returns:  round seen mask
  */
    const(BitMask) round_seen_mask() const pure nothrow @nogc {
        return _round_seen_mask;
    }

    private {
        Round _round; /// The where the event has been created
        Round _round_received; /// The round in which the event has been voted to be received
        BitMask _round_received_mask; /// Voting mask for the received rounds
    }

    /**
     * Attach the mother round to this event
     * Params:
     *   hashgraph = the graph which produces this event
     */
    package void attach_round(HashGraph hashgraph) pure nothrow {
        if (!_round) {
            _round = _mother._round;
        }
    }

    immutable uint id;

    /**
    *  Makes the event a witness  
    */
    package void witness_event(ulong node_size) nothrow
    in {
        assert(!_witness);
    }
    do {
        _witness = new Witness(this, node_size);
    }

    immutable size_t node_id; /// Node number of the event


    void initializeReceivedOrder() pure nothrow @nogc {
        if (_received_order is int.init) {
            _received_order = -2;
        }
    }


    /**
     * Sets the received order of the event
     * Params:
     *   iteration_count = iteration count used for debugging
     */
    private void received_order(ref uint iteration_count) pure nothrow {
        if (isFatherLess) {
            if (_mother) {
                if (_mother._received_order is int.init) {
                    _mother.received_order(iteration_count);
                }
                _received_order = expected_order();
            }
            return;
        }

        if (_received_order is int.init) {
            _received_order = expected_order();
        }

        const expected = expected_order();

        if ((expected - _received_order) > 0) {
            _received_order = expected;
            if (_son) {
                _son.received_order(iteration_count);
            }
            if (_daughter) {
                _daughter.received_order(iteration_count);
            }
        }
        else if ((expected - _received_order) < 0) {
            if (_father) {
                _father.received_order(iteration_count);
            }
            if (_mother) {
                _mother.received_order(iteration_count);
            }
            _received_order = expected_order();
            if (_son) {
                _son.received_order(iteration_count);
            }
            if (_daughter) {
                _daughter.received_order(iteration_count);
            }

        }
    }


    /**
      * Connect the event to the hashgraph
      * Params:
      *   hashgraph = event owner 
      */
    package final void connect(HashGraph hashgraph)
    in {
        assert(hashgraph.areWeInGraph);

    }
    out {
        assert(event_package.event_body.mother && _mother || !_mother);
        assert(event_package.event_body.father && _father || !_father);
    }
    do {
        if (connected) {
             return;     
        }
        scope (exit) {
            if (_mother) {
                Event.check(this.altitude - _mother.altitude is 1,
                    ConsensusFailCode.EVENT_ALTITUDE);
                Event.check(channel == _mother.channel,
                    ConsensusFailCode.EVENT_MOTHER_CHANNEL);
            }
            hashgraph.front_seat(this);
            if (Event.callbacks) {
                Event.callbacks.connect(this);
            }
        }

        _mother = hashgraph.register(event_package.event_body.mother);
        if (_mother) {
            check(!_mother._daughter, ConsensusFailCode.EVENT_MOTHER_FORK);
            _mother._daughter = this;
            _father = hashgraph.register(event_package.event_body.father);
            _round = ((father) && (father.round.number >= mother.round.number)) ? _father._round : _mother._round; 
            if (_father) {
                check(!_father._son, ConsensusFailCode.EVENT_FATHER_FORK);
                _father._son = this;
            }
            if (callbacks) {
                callbacks.round(this);
            }

            uint received_order_iteration_count;
            received_order(received_order_iteration_count);
            hashgraph.received_order_statistic(received_order_iteration_count);
            with (hashgraph) {
                mixin Log!(received_order_statistic);
            }


            const new_witness = calc_witness_strong_seen_masks(hashgraph);
            calc_youngest_ancestors(hashgraph);
            if (new_witness) {
                hashgraph._rounds.next_round(this);
            }
            if (round.number > mother.round.number) {
                _witness = new Witness(this, hashgraph.node_size);
                
                if (new_witness) {
                    foreach (i;0 .. _witness_strong_seen_masks.length)
                    {
                        _witness._prev_seen_witnesses[i] = _witness_strong_seen_masks[i][node_id];
                        _witness._prev_strongly_seen_witnesses[i] = _witness_strong_seen_masks[i].isMajority(hashgraph);
                    }
                    clear_witness_strong_seen_masks(hashgraph);
                    clear_youngest_ancestors(hashgraph);
                }
                else {
                    _round.add(this);
                    foreach(idx; father._witness_strong_seen_masks
                        .map!(mask => (mask.count >= 1))
                        .enumerate
                        .filter!(b => b.value)
                        .map!(b => b.index)) {
                            _witness._prev_strongly_seen_witnesses |= round.events[idx]._witness._prev_strongly_seen_witnesses;
                            foreach(j; 0 .. _witness_strong_seen_masks.length) {
                                if (round.events[idx]._witness._prev_seen_witnesses[j]) {
                                    _witness._prev_seen_witnesses[j] = round.events[idx]._witness._prev_seen_witnesses[j];
                                }
                            }
                    }
                    foreach(j; 0 .. _witness_strong_seen_masks.length) {
                        if (mother._witness_strong_seen_masks[j][mother.node_id] && mother.round.number + 1 == round.number) {
                            _witness._prev_seen_witnesses[j] = mother._witness_strong_seen_masks[j][mother.node_id];
                        }
                    }
                }
                with (hashgraph) {
                    mixin Log!(strong_seeing_statistic);
                }
                if (callbacks) {
                    callbacks.witness(this);
                }
                foreach(i; 0 .. hashgraph.node_size) {
                    calc_vote(hashgraph, i);
                }
                    
            }
        }
        else if (!isEva && !hashgraph.joining && !hashgraph.rounds.isEventInLastDecidedRound(this))  {
            check(false, ConsensusFailCode.EVENT_MOTHER_LESS);
        }        
    }

    void calc_youngest_ancestors(HashGraph hashgraph) {
        // __write("AIORSTNOARTNEIART");
        if (hashgraph.__debug_print) {
            __write("AIORSTNOARTNEIART");
            __write("EVENT: %s, has _youngest_ancestors: %s", id, _youngest_ancestors);
        }
        if (!father || mother.round.number > father.round.number) {
            _youngest_ancestors = _mother._youngest_ancestors;
            // _witness_descendants = mother._witness_descendants;
            return;
        }

        // if (hashgraph.__debug_print) {
        //     __write("EVENT: %s, has _youngest_ancestors: %s", id, _youngest_ancestors.filter!(e => e !is null).map!(e => e.id).array);
        // }
        if (father.round is mother.round) {
            _youngest_ancestors = _mother._youngest_ancestors.dup();
            // _witness_descendants = mother._witness_descendants;
        }
        else {
            _youngest_ancestors = new Event[hashgraph.node_size];
        }

        // if (hashgraph.__debug_print) {
        //     __write("EVENT: %s, has _youngest_ancestors: %s", id, _youngest_ancestors.filter!(e => e !is null).map!(e => e.id).array);
        // }
        iota(_father._youngest_ancestors.length)
            .filter!((ulong i) => _father._youngest_ancestors[i] !is null)
            .filter!((ulong i) => _youngest_ancestors[i] is null || _father._youngest_ancestors[i].received_order > _youngest_ancestors[i].received_order)
            .each!((ulong i) => _youngest_ancestors[i] = _father._youngest_ancestors[i]);
        _youngest_ancestors[_father.node_id] = _father;
        
        // const father_unique_descendants = (~_witness_descendants & father._witness_descendants);
        // father_unique_descendants[]
        //     .map!(i => _round._events[i])
        //     .filter!(e => e._witness._ancestors_tide[node_id] !is null)
        //     .filter!(e  => higher(e._witness._ancestors_tide[node_id].received_order, received_order))
        //     .each!(e => e._witness._ancestors_tide[node_id] = this);

        // _witness_descendants |= father._witness_descendants;
        if (hashgraph.__debug_print) {
            __write("ENDOFFUNC EVENT: %s, has _youngest_ancestors: %s", id, _youngest_ancestors.filter!(e => e !is null).map!(e => e.id).array);
        }
    }

    void clear_youngest_ancestors(HashGraph hashgraph) {
        _youngest_ancestors = new Event[hashgraph.node_size];
        _youngest_ancestors[node_id] = this;
    }

    void calc_vote(HashGraph hashgraph, ulong vote_node_id) {
        Round voting_round = hashgraph._rounds.voting_round_per_node[vote_node_id];
        Event voting_event = voting_round._events[vote_node_id];
        
        if (voting_round.number >= round.number) { return; }
        if (voting_round.number + 1 == round.number ) {
            _witness._vote_on_earliest_witnesses[vote_node_id] = _witness._prev_seen_witnesses[vote_node_id];
            return;
        }
        if (voting_event is null) {
            hashgraph._rounds.vote(vote_node_id, hashgraph);
            return;
        }
        auto votes = _witness._prev_strongly_seen_witnesses[]
                        .map!(i => round.previous.events[i]._witness._vote_on_earliest_witnesses[vote_node_id]);
        const yes_votes = votes.count;
        const no_votes = votes.walkLength - yes_votes;
        _witness._vote_on_earliest_witnesses[vote_node_id] = (yes_votes >= no_votes);
        if (hashgraph.isMajority(yes_votes) || hashgraph.isMajority(no_votes)) {
            voting_round.famous_mask[vote_node_id] = (yes_votes >= no_votes);
            if (yes_votes < no_votes) {
                __write("A NOTE HAS BEEN VOTED INFAMOUS");
            }
            hashgraph._rounds.vote(vote_node_id, hashgraph);
        }
    }

    private bool calc_witness_strong_seen_masks(HashGraph hashgraph) {
        pragma(msg, "fixme(bbh) We are currently missing which previous round witnesses you can strongly
         see if the method by which you became a witness was not this function but just that father.round>mother.round.
         A quick fix to this is just having the witnesses keep 2 bitarrays; one for what you can see in the previous round
         and the next, or implementing another way to check for strongly seen. One could also make a special call that just
         search recursively whenever a witness becomes a witness by this second method");
        if (!father || mother.round.number > father.round.number) {
            _witness_strong_seen_masks = _mother._witness_strong_seen_masks.dupBitMaskArray;
            
            return false;
        }

        if (father.round is mother.round) {
            _witness_strong_seen_masks = _mother._witness_strong_seen_masks.dupBitMaskArray;
        }
        
        _witness_strong_seen_masks[node_id][node_id] = true;
        
        const _father_masks = father._witness_strong_seen_masks;
        foreach (i;0 .. _father_masks.length) {
            _witness_strong_seen_masks[i] |= _father_masks[i];

            if (_father_masks[i][father.node_id]) {
                _witness_strong_seen_masks[i][node_id] = true;
            }
        }
        const strongly_seen_votes = _witness_strong_seen_masks.filter!(mask => mask.isMajority(hashgraph)).count;
        const result = hashgraph.isMajority(strongly_seen_votes);
        return hashgraph.isMajority(strongly_seen_votes);
    }

    void clear_witness_strong_seen_masks(HashGraph hashgraph) {
        foreach (ref mask; _witness_strong_seen_masks) {
            mask.clear();
        }
        _witness_strong_seen_masks[node_id][node_id] = true;

    }

    /**
     * Disconnect this event from hashgraph
     * Used to remove events which are no longer needed 
     * Params:
     *   hashgraph = event owner
     */
    @trusted
    final private void disconnect(HashGraph hashgraph)
    in {
        assert(!_mother, "Event with a mother can not be disconnected");
    }
    do {
        hashgraph.eliminate(fingerprint);
        if (_witness) {
            _round.remove(this);
            _witness.destroy;
            _witness = null;
        }
        if (_daughter) {
            _daughter._mother = null;
        }
        if (_son) {
            _son._father = null;
        }
        _daughter = _son = null;
    }

    /**
     * Mother event
     * Throws: EventException if the mother has been grounded
     * Returns: mother event 
     */
    final const(Event) mother() const pure {
        Event.check(!isGrounded, ConsensusFailCode.EVENT_MOTHER_GROUNDED);
        return _mother;
    }

    /**
     * Mother event
     * Throws: EventException if the mother has been grounded
     * Returns: mother event 
     */
    final const(Event) father() const pure {
        Event.check(!isGrounded, ConsensusFailCode.EVENT_FATHER_GROUNDED);
        return _father;
    }

    @nogc pure nothrow const final {
        /**
  * The event-body from this event 
  * Returns: event-body
  */
        ref const(EventBody) event_body() {
            return event_package.event_body;
        }

        /**
     * The recived round for this event
     * Returns: received round
     */
        const(Round) round_received() {
            return _round_received;
        }

        /**
     * Channel from which this event has received
     * Returns: channel
     */
        immutable(Pubkey) channel() {
            return event_package.pubkey;
        }

        /**
     * Get the mask of the received rounds
     * Returns: received round mask 
     */
        const(BitMask) round_received_mask() {
            return _round_received_mask;
        }

        /**
     * Checks if this event is the last one on this node
     * Returns: true if the event is in front
     */
        bool isFront() {
            return _daughter is null;
        }

        /**
     * Check if an evnet has around 
     * Returns: true if an round exist for this event
     */

        bool hasRound() {
            return (_round !is null);
        }

        /**
     * Round of this event
     * Returns: round
     */
        const(Round) round()
        out (result) {
            assert(result, "Round must be set before this function is called");
        }
        do {
            return _round;
        }
    /**
     * Gets the witness infomatioin of the event
     * Returns: 
     * if this event is a witness the witness is returned
     * else null is returned
     */
        const(Witness) witness() {
            return _witness;
        }

        bool isWitness() {
            return _witness !is null;
        }
        
        bool isFamous() {
            return isWitness && round.famous_mask[node_id];
        }
        /**
         * Get the altitude of the event
         * Returns: altitude
         */
        immutable(int) altitude() {
            return event_package.event_body.altitude;
        }

        /**
         *  Calculates the order of this event
         * Returns: order ( max(m+1, f+1 ). 
         */
        int expected_order() const pure nothrow @nogc {
            const m = (_mother) ? _mother._received_order : int.init;
            const f = (_father) ? _father._received_order : int.init;
            int result = (m - f > 0) ? m : f;
            result++;
            result = (result is int.init) ? 1 : result;
            return result;
        }
        /**
          * Is this event owner but this node 
          * Returns: true if the evnet is owned
          */
        bool nodeOwner() const pure nothrow @nogc {
            return node_id is 0;
        }

        /**
         * Gets the event order number 
         * Returns: order
         */
        int received_order() const pure nothrow @nogc
        in {
            assert(isEva || (_received_order !is int.init), "The received order of this event has not been defined");
        }
        do {
            return _received_order;
        }

        /**
       * Checks if the event is connected in the graph 
       * Returns: true if the event is corrected 
       */
        bool connected() const pure @nogc {
            return (_mother !is null);
        }

        /**
       * Gets the daughter event
       * Returns: the daughter
       */

        const(Event) daughter() {
            return _daughter;
        }

        /**
       * Gets the son of this event
       * Returns: the son
       */
        const(Event) son() {
            return _son;
        }
        /**
       * Get 
       * Returns: 
       */
        const(Document) payload() {
            return event_package.event_body.payload;
        }

        ref const(EventBody) eventbody() {
            return event_package.event_body;
        }

        //True if Event contains a payload or is the initial Event of its creator
        bool containPayload() {
            return !payload.empty;
        }

        // is true if the event does not have a mother or a father
        bool isEva()
        out (result) {
            if (result) {
                assert(event_package.event_body.father is null);
            }
        }
        do {
            return (_mother is null) && (event_package.event_body.mother is null);
        }

        /// A father less event is an event where the ancestor event is connect to an Eva event without an father event
        /// An Eva is is also defined as han father less event
        /// This also means that the event has not valid order and must not be included in the epoch order.
        bool isFatherLess() {
            return isEva || !isGrounded && (event_package.event_body.father is null) && _mother
                .isFatherLess;
        }

        bool hasOrder() {
            return _received_order !is int.init;
        }

        bool isGrounded() {
            return (_mother is null) && (event_package.event_body.mother !is null) ||
                (_father is null) && (event_package.event_body.father !is null);
        }

        immutable(Buffer) fingerprint() {
            return event_package.fingerprint;
        }

        Range!true opSlice() {
            return Range!true(this);
        }
    }

    @nogc
    package Range!false opSlice() pure nothrow {
        return Range!false(this);
    }

    @nogc
    struct Range(bool CONST = true) {
        private Event current;
        @trusted
        this(const Event event) pure nothrow {
            current = cast(Event) event;
        }

        pure nothrow {
            bool empty() const {
                return current is null;
            }

            static if (CONST) {
                const(Event) front() const {
                    return current;
                }
            }
            else {
                ref Event front() {
                    return current;
                }
            }

            alias back = front;

            void popFront() {
                if (current) {
                    current = current._mother;
                }
            }

            void popBack() {
                if (current) {
                    current = current._daughter;
                }
            }

            Range save() {
                return Range(current);
            }
        }
    }

    static assert(isInputRange!(Range!true));
    static assert(isForwardRange!(Range!true));
    static assert(isBidirectionalRange!(Range!true));
}
@safe
static BitMask[] dupBitMaskArray(BitMask[] masksIn) {
    return masksIn.map!(m => m.dup).array;
}
