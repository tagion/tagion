/// HashGraph Event
module tagion.hashgraph.Event;

//import std.stdio;

import std.datetime; // Date, DateTime
import std.algorithm.iteration : cache, each, filter, fold, joiner, map, reduce;
import std.algorithm.searching : all, any, canFind, count, until;
import std.algorithm.sorting : sort;
import std.algorithm.comparison : min, max;
import std.array : array;
import std.conv;
import std.format;
import std.range;
import std.range.primitives : isBidirectionalRange, isForwardRange, isInputRange, walkLength;
import std.stdio;
import std.traits;
import std.typecons;
import tagion.basic.Types : Buffer;
import tagion.basic.basic : isinit;
import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Round;
import tagion.monitor.Monitor : EventMonitorCallbacks;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONRecord;
import tagion.logger.Logger;
import tagion.utils.BitMask : BitMask;
import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;
import tagion.basic.Debug;

/// HashGraph Event
@safe
class Event {
    package static bool scrapping;

    import tagion.basic.ConsensusExceptions;

    alias check = Check!EventConsensusException;
    protected static uint _count;

    package int pseudo_time_counter;

    package {

        Round _round; /// The where the event has been created
        Witness _witness; /// Contains information for the witness events
    }
    immutable uint node_id; /// Node number of the event
    immutable uint id; /// Event id
    immutable(EventPackage*) event_package; /// Then exchanged event information

    BitMask _witness_seen_mask; /// Witness seen in previous round
    BitMask _intermediate_seen_mask;
    // This is the internal pointer to the connected Event's
    package Event _mother; /// Points to the self-parent
    package Event _father; /// Points to other-parent
    protected {
        Event _daughter; /// Points to the direct self-ancestor
        Event _son; /// Points to the direct other-ancestor
        int _order; /// Event order higher value means after
        Round _round_received; /// The round in which the event has been voted to be received
    }
    static Topic topic = Topic("hashgraph_event");
    bool top;
    bool _intermediate_event;

    @nogc
    static uint count() nothrow {
        return _count;
    }

    static bool lower_order(const Event a, const Event b) pure nothrow {
        if (!a) {
            return false;
        }
        if (!b) {
            return true;
        }

        if (a.order < b.order) {
            return false;
        }
        if (a.order == b.order) {
            auto a_father = a[].filter!(e => e._father !is null)
                .map!(e => e._father);
            auto b_father = b[].filter!(e => e._father !is null)
                .map!(e => e._father);
            if (a_father.empty) {
                if (b_father.empty) {
                    return lower_order(a._mother, b._mother);
                }
                return true;
            }
            if (b_father.empty) {
                return false;
            }
            return higher_order(a_father.front, b_father.front);
        }
        return false;
    }

    static bool higher_order(const Event a, const Event b) pure nothrow {
        if (!a) {
            return false;
        }
        if (!b) {
            return true;
        }

        if (a.order > b.order) {
            return true;
        }
        if (a.order == b.order) {
            auto a_father = a[].filter!(e => e._father !is null)
                .map!(e => e._father);
            auto b_father = b[].filter!(e => e._father !is null)
                .map!(e => e._father);
            if (a_father.empty) {
                if (b_father.empty) {
                    return higher_order(a._mother, b._mother);
                }
                return false;
            }
            if (b_father.empty) {
                return true;
            }
            return higher_order(a_father.front, b_father.front);
        }
        return false;
    }

    /**
     * Builds an event from an eventpackage
     * Params:
     *   epack = event-package to build from
     *   hashgraph = the hashgraph which produce the event
     */
    package this(
            immutable(EventPackage)* epack,
            HashGraph hashgraph,
            const uint check_graphtype = 0
    )
    in (epack !is null)
    do {
        event_package = epack;
        this.id = hashgraph.next_event_id;
        this.node_id = hashgraph.getNode(channel).node_id;
        _count++;
        _witness_seen_mask[node_id] = true;
    }

    protected ~this() {
        _count--;
    }

    invariant {
        if (!scrapping && this !is null) {
            if (_mother) {
                assert(_mother._daughter is this);
                assert(
                        event_package.event_body.altitude - _mother
                        .event_package.event_body.altitude is 1);
                assert(_order is int.init || (_order - _mother._order > 0));
            }
            if (_father) {
                pragma(msg, "fixme(bbh) this test should be reimplemented once new witness def works");
                assert(_order is int.init || (_order - _father._order > 0));
            }
        }
    }

    /**
     * The witness event will point to the witness object
     * This object contains information about the voting etc. for the witness event
     */
    @safe
    class Witness {
        protected static uint _count;
        @nogc static uint count() nothrow {
            return _count;
        }

        private {
            BitMask _intermediate_event_mask;
            BitMask _previous_strongly_seen_mask;
            BitMask _voted_yes_mask; /// Witness in the next round which has voted

        }
        const BitMask previous_witness_seen_mask;
        BitMask seen_voting_mask;
        bool __seen_decided(size_t voters) const pure nothrow {
            const seen_votes = seen_voting_mask.count;
            const N = _round.node_size;
            return ((voters == 0) || isMajority(min(seen_votes, yes_votes), N) ||
                    seen_votes >= voters) && !isUndecided(seen_votes, N);
        }

        @nogc final const pure nothrow {
            const(BitMask) previous_strongly_seen_mask() {
                return _previous_strongly_seen_mask;
            }

            const(BitMask) intermediate_event_mask() {
                return _intermediate_event_mask;
            }

            uint yes_votes() {
                return cast(uint)(_voted_yes_mask.count);
            }

            bool decided() {
                const N = _round.node_size;
                return isMajority(yes_votes, N) ||
                !isMajority(yes_votes+N-voters, N) ||
                isMajority(voters - yes_votes, N);
            }

            uint voters() {
                if (_round.next) {
                return cast(uint)_round.next.events.filter!(e => e !is null).count; 
                }
                return 0;
    }   
            uint no_votes() {
                return voters - yes_votes;
            }
            const(BitMask) voted_yes_mask() {
                return _voted_yes_mask;
            }

            bool weak() {
                return _mother && _round.previous && (_round.previous.events[node_id] is null);
            }
        }

        private void voteYes(const size_t voting_node_id) pure nothrow {
            if (!_voted_yes_mask[voting_node_id]) {
                _voted_yes_mask[voting_node_id] = true;
            }
        }

        /**
         * Contsruct a witness of an event
         * Params:
         *   owner_event = the event which is voted to be a witness
         *   seeing_witness_in_previous_round_mask = The witness seen from this event to the previous witness.
         */
        private this() nothrow {
            _count++;
            _witness = this;
            if (father_witness_is_leading) {
                _previous_strongly_seen_mask = _mother._intermediate_seen_mask |

                    _father.round.events[_father.node_id].witness
                        .previous_strongly_seen_mask;

                previous_witness_seen_mask = _witness_seen_mask |
                    _father.round.events[_father.node_id].witness
                        .previous_witness_seen_mask;
            }
            else {
                _previous_strongly_seen_mask = _intermediate_seen_mask.dup;
                previous_witness_seen_mask = _witness_seen_mask;
            }
            _intermediate_event_mask[node_id] = true;

            _intermediate_seen_mask.clear;
            _intermediate_event = false;
            _witness_seen_mask.erase;
            _witness_seen_mask[node_id] = true;
        }

        bool hasVoted() const pure nothrow @nogc {
            return _round !is null;
        }

        void vote(HashGraph hashgraph) nothrow
        in ((!hasVoted), "This witness has already voted")
        do {
            hashgraph._rounds.set_round(this.outer);
            /// Counting yes/no votes from this witness to witness in the previous round
            if (round.previous && (round.previous.events[node_id]!is null) && !round.previous.events[node_id].witness
                .weak) {
                auto previous_witness_events = _round.previous.events;
                foreach (n, previous_witness_event; previous_witness_events) {
                    //auto previous_witness_event = previous_witness_events[n];
                    if (previous_witness_event) {
                        auto vote_for_witness = previous_witness_event._witness;
                        const seen_strongly = _previous_strongly_seen_mask[n];
                        //const seen_strongly = previous_witness_seen_mask[n];
                        if (seen_strongly) {
                            vote_for_witness.voteYes(node_id);
                            view(previous_witness_event);
                        }
                    }
                }
            }
        }

        ~this() {
            _count--;
        }

    }

    bool father_witness_is_leading() const pure nothrow {
        return _father &&
            higher(_father._round.number, _mother._round.number) &&
            _father.round.events[_father.node_id];
    }

    bool calc_strongly_seen(HashGraph hashgraph) const pure nothrow
    in (_father, "Calculation of strongly seen only makes sense if we have a father")
    do {
        if (father_witness_is_leading) {
            return true;
        }
        const majority_intermediate_seen = isMajority(_intermediate_seen_mask, hashgraph);
        if (majority_intermediate_seen) {
            const vote_strongly_seen = _mother.round
                .events
                .filter!(e => e !is null)
                .map!(e => e._witness)
                .map!(w => w._intermediate_event_mask[node_id])
                .count;
            return isMajority(vote_strongly_seen, hashgraph.node_size);
        }
        return false;
    }

    static EventMonitorCallbacks callbacks;

    static void view(const(Event) e) nothrow {
        if (callbacks && e) {
            callbacks.connect(e);
        }
    }

    static void view(R)(R range) nothrow if (isInputRange!R && is(ElementType!R : const(Event))) {
        if (callbacks) {
            range.each!(e => view(e));
        }
    }

    invariant {
        if (_round_received !is null && _round_received.number > 1 && _round_received.previous !is null) {

            assert(_round_received.number == _round_received.previous.number + 1,
                    format("Round was not added by 1: current: %s previous %s",
                    _round_received.number, _round_received.previous.number));
        }
    }

    /**
    *  Makes the event a witness  
    */
    package final void witness_event() nothrow
    in (!_witness, "Witness has already been set")
    out {
        assert(_witness, "Witness should be set");
    }
    do {
        new Witness;
    }

    final void initializeOrder() pure nothrow @nogc {
        if (order.isinit) {
            _order = -1;
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
            view(this);
            hashgraph.refinement.payload(event_package);
        }

        _mother = hashgraph.register(event_package.event_body.mother);
        if (!_mother) {
            if (!isEva &&  !hashgraph.rounds.isEventInLastDecidedRound(this)) {
                check(false, ConsensusFailCode.EVENT_MOTHER_LESS);
            }
            return;
        }

        check(!_mother._daughter, ConsensusFailCode.EVENT_MOTHER_FORK);
        _mother._daughter = this;
        _father = hashgraph.register(event_package.event_body.father);
        _order = ((_father && higher(_father.order, _mother.order)) ? _father.order : _mother.order) + 1;
        _witness_seen_mask |= _mother._witness_seen_mask;
        _intermediate_seen_mask |= _mother._intermediate_seen_mask;
        if (_father) {
            check(!_father._son, ConsensusFailCode.EVENT_FATHER_FORK);
            _father._son = this;
            BitMask new_witness_seen;
            if (_father._round.number == _mother._round.number) {
                _witness_seen_mask |= _father._witness_seen_mask;
                _intermediate_seen_mask |= _father._intermediate_seen_mask;
                new_witness_seen = _father._witness_seen_mask - _mother
                    ._witness_seen_mask;
            }
            else {
                new_witness_seen = _witness_seen_mask;
            }
            if (!new_witness_seen[].empty) {
                _intermediate_event = true;
                _intermediate_seen_mask[node_id] = true;
                auto max_round = maxRound;
                new_witness_seen[]
                    .filter!((n) => max_round.events[n]!is null)
                    .map!((n) => max_round.events[n]._witness)
                    .filter!((witness) => witness._intermediate_event_mask[node_id])
                    .each!((witness) => witness._intermediate_event_mask[node_id] = true);
            }
            const strongly_seen = calc_strongly_seen(hashgraph);
            if (strongly_seen) {
                new Witness;
                _witness.vote(hashgraph);
                hashgraph._rounds.check_decide_round;
                return;
            }
        }
        hashgraph._rounds.set_round(this);
    }

    Round maxRound() nothrow pure @nogc {
        if (_round) {
            return _round;
        }
        if (_father && higher(_father._round.number, _mother._round.number)) {
            return _father._round;
        }
        return _mother._round;
    }

    /**
     * Disconnect this event from hashgraph
     * Used to remove events which are no longer needed 
     * Params:
     *   hashgraph = event owner
     */
    final package void disconnect(HashGraph hashgraph) nothrow @trusted
    in (!_mother, "Event with a mother can not be disconnected")
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

    @nogc pure nothrow final {
        void round_received(Round r)
        in (!_round_received, "Received round has been set")
        do {
            _round_received = r;
        }

        package Witness witness()
        in (_witness, "Event is not a witness")
        do {
            return _witness;
        }
    }

    @nogc pure nothrow const final {
        /**
     * The received round for this event
     * Returns: received round
     */
        const(Round) round_received() scope {
            return _round_received;
        }

        /**
      * The event-body from this event 
      * Returns: event-body
      */
        ref const(EventBody) event_body() {
            return event_package.event_body;
        }

        /**
     * Channel from which this event has received
     * Returns: channel
     */
        immutable(Pubkey) channel() {
            return event_package.pubkey;
        }

        /**
     * Checks if this event is the last one on this node
     * Returns: true if the event is in front
     */
        bool isFront() {
            return _daughter is null;
        }

        /**
     * Check if an event has around 
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

        /**
         * Get the altitude of the event
         * Returns: altitude
         */
        immutable(int) altitude() scope {
            return event_package.event_body.altitude;
        }

        /**
          * Is this event owner but this node 
          * Returns: true if the event is owned
          */
        bool nodeOwner() {
            return node_id is 0;
        }

        /**
         * Gets the event order number 
         * Returns: order
         */
        int order() {
            return _order;
        }

        /**
       * Checks if the event is connected in the graph 
       * Returns: true if the event is corrected 
       */
        bool connected() {
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
            return isEva || !isGrounded &&
                (event_package.event_body.father is null) && _mother.isFatherLess;
        }

        bool isGrounded() {
            return (_mother is null) &&
                (event_package.event_body.mother !is null) ||
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
        static if (CONST) {
            this(const Event event) pure nothrow @trusted {
                current = cast(Event) event;
            }
        }
        else {
            this(Event event) pure nothrow {
                current = event;
            }
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
