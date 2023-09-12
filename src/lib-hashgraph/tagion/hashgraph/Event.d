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
import std.algorithm.iteration : map, each, filter, cache, fold, joiner, reduce;
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
import tagion.hashgraph.Round;
import tagion.hashgraphview.EventMonitorCallbacks;
import tagion.utils.BitMask : BitMask;

import std.typecons : No;

import std.traits;

import std.stdio;


/// HashGraph Event
@safe
class Event {
    package static bool scrapping;

    import tagion.basic.ConsensusExceptions;

    alias check = Check!EventConsensusException;
    protected static uint _count;

    package Event[] _youngest_son_ancestors;

    package {
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
        event_package = epack;
        this.id = hashgraph.next_event_id;
        this.node_id = hashgraph.getNode(channel).node_id;
        _count++;
    }

    protected ~this() {
        _count--;
    }

    invariant {
        if (!scrapping && this !is null) {
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
            BitMask _vote_on_earliest_witnesses;
            BitMask _prev_strongly_seen_witnesses;
            BitMask _prev_seen_witnesses;
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
            _count++;
        }

        ~this() {
            _count--;
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

    package {
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
        _youngest_son_ancestors = new Event[node_size];
        _youngest_son_ancestors[node_id] = this;
    }

    immutable size_t node_id; /// Node number of the event

    void initializeReceivedOrder() pure nothrow @nogc {
        if (_received_order is int.init) {
            // _received_order = -2;
            _received_order = -1;
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
            // refinement
            hashgraph.refinement.payload(event_package);
        }

        _mother = hashgraph.register(event_package.event_body.mother);
        if (!_mother) {
            if (!isEva && !hashgraph.joining && !hashgraph.rounds.isEventInLastDecidedRound(this)) {
                check(false, ConsensusFailCode.EVENT_MOTHER_LESS);
            }
            return;
        }

        check(!_mother._daughter, ConsensusFailCode.EVENT_MOTHER_FORK);
        _mother._daughter = this;
        _father = hashgraph.register(event_package.event_body.father);
        _round = ((father) && higher(father.round.number, mother.round.number)) ? _father._round : _mother._round;
        if (_father) {
            check(!_father._son, ConsensusFailCode.EVENT_FATHER_FORK);
            _father._son = this;
        }
        if (callbacks) {
            callbacks.round(this);
        }
        _received_order = (_father && higher(_father._received_order, _mother._received_order)) ? _father._received_order + 1 : _mother._received_order + 1;
        with (hashgraph) {
            mixin Log!(received_order_statistic);
        }

        calc_youngest_son_ancestors(hashgraph);
        BitMask strongly_seen_nodes = calc_strongly_seen_nodes(hashgraph);
        if (strongly_seen_nodes.isMajority(hashgraph)) {
            hashgraph._rounds.next_round(this);
        }
        if (!higher(round.number, mother.round.number)) {
            return;
        }

        _witness = new Witness(this, hashgraph.node_size);

        _witness._prev_strongly_seen_witnesses = strongly_seen_nodes;
        _witness._prev_seen_witnesses = BitMask(_youngest_son_ancestors.map!(e => (e !is null && !higher(round.number-1, e.round.number))));
        if (!strongly_seen_nodes.isMajority(hashgraph)) {
            _round.add(this);
        }
        with (hashgraph) {
            mixin Log!(strong_seeing_statistic);
        }
        if (callbacks) {
            callbacks.witness(this);
        }
        foreach (i; 0 .. hashgraph.node_size) {
            calc_vote(hashgraph, i);
        }
        // if (hashgraph.__debug_print) {
        //     __write("EVENT: %s, Youngest_ancestors: %s", id, _youngest_son_ancestors.filter!(e => e !is null).map!(e => e.id));
        // }
    }

    private BitMask calc_strongly_seen_nodes(const HashGraph hashgraph) {
        auto see_through_matrix = _youngest_son_ancestors 
                                    .filter!(e => e !is null && e.round is round)
                                    .map!(e => e._youngest_son_ancestors
                                        .map!(e => e !is null && e.round is round));
        
        scope strongly_seen_votes = new size_t[hashgraph.node_size];
        see_through_matrix.each!(row => row.enumerate.each!(elm => strongly_seen_votes[elm.index] += elm.value));
        return BitMask(strongly_seen_votes.map!(votes => hashgraph.isMajority(votes)));
    }

    private void calc_youngest_son_ancestors(const HashGraph hashgraph) {
        if (!_father) {
            _youngest_son_ancestors = _mother._youngest_son_ancestors;
            return;
        }

        _youngest_son_ancestors = _mother._youngest_son_ancestors.dup();
        _youngest_son_ancestors[node_id] = this;
        iota(hashgraph.node_size)
            .filter!(node_id => _father._youngest_son_ancestors[node_id]!is null)
            .filter!(node_id => _youngest_son_ancestors[node_id] is null || _father._youngest_son_ancestors[node_id]
            .received_order > _youngest_son_ancestors[node_id].received_order)
            .each!(node_id => _youngest_son_ancestors[node_id] = _father._youngest_son_ancestors[node_id]);
    }

    package void calc_vote(HashGraph hashgraph, size_t vote_node_id) {
        Round voting_round = hashgraph._rounds.voting_round_per_node[vote_node_id];
        Event voting_event = voting_round._events[vote_node_id];

        if (!higher(round.number, voting_round.number)) {
            return;
        }
        if (voting_round.number + 1 == round.number) {
            _witness._vote_on_earliest_witnesses[vote_node_id] = _witness._prev_seen_witnesses[vote_node_id];
            return;
        }
        if (voting_event is null) {
            hashgraph._rounds.vote(hashgraph, vote_node_id);
            return;
        }
        auto votes = _witness._prev_strongly_seen_witnesses[].map!(
                i => round.previous.events[i]._witness._vote_on_earliest_witnesses[vote_node_id]);
        const yes_votes = votes.count;
        const no_votes = votes.walkLength - yes_votes;
        _witness._vote_on_earliest_witnesses[vote_node_id] = (yes_votes >= no_votes);
        if (hashgraph.isMajority(yes_votes) || hashgraph.isMajority(no_votes)) {
            voting_round.famous_mask[vote_node_id] = (yes_votes >= no_votes);
            hashgraph._rounds.vote(hashgraph, vote_node_id);
        }
    }

    /**
     * Disconnect this event from hashgraph
     * Used to remove events which are no longer needed 
     * Params:
     *   hashgraph = event owner
     */
    @trusted
    final package void disconnect(HashGraph hashgraph)
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
        {
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