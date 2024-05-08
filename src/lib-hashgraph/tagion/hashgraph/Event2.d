/// HashGraph Event
module tagion.hashgraph.Event2;

//import std.stdio;

import std.datetime; // Date, DateTime
import std.algorithm.iteration : cache, each, filter, fold, joiner, map, reduce;
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
import tagion.basic.Types : Buffer;
import tagion.basic.basic : EnumText, basename, buf_idup, this_dot;
import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic : EvaPayload, EventBody, EventPackage, Tides, higher, isAllVotes, isMajority;
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
import current_event = tagion.hashgraph.Event;

/// HashGraph Event
@safe
class Event2 : current_event.Event {
    version (none) package static bool scrapping;

    import tagion.basic.ConsensusExceptions;

    alias check = Check!EventConsensusException;
    version (none) protected static uint _count;

    //package Event[] _youngest_son_ancestors;

    //package int pseudo_time_counter;
    version (none) package {
        // This is the internal pointer to the connected Event's
        Event _mother;
        Event _father;
        Event _daughter;
        Event _son;

        long _order;
        // The withness mask contains the mask of the nodes
        // Which can be seen by the next rounds witness
        Witness _witness;
        // BitMask _round_seen_mask;
    }

    BitMask _witness_seen_mask; /// Witness seen in privious round
    BitMask _intermediate_seen_mask;
    bool _intermediate_event;
    //current_event.Event[] _intermediate_events_seen;
    //    BitMask[] strongly_seen_matrix;
    //    BitMask strongly_seen_mask;
    version (none) @nogc
    static uint count() nothrow {
        return _count;
    }

    //bool error;

    //Topic topic = Topic("hashgraph_event");

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
    in (hashgraph.graphtype == 2)
    do {

        super(epack, hashgraph, 2);
        //        if (!_mother) {
        //            strongly_seen_matrix.length=hashgraph.node_size;
        //            strongly_seen_matrix[node_id][node_id]=true;
        //        }
        //onnect(hashgraph);
        _witness_seen_mask[node_id] = true;
        version (none) {
            if (_mother) {
                _witness_seen_mask |= (cast(Event2) _mother)._witness_seen_mask;
            }
            if (_father) {
                _witness_seen_mask |= (cast(Event2) _father)._witness_seen_mask;
            }
            if (_witness_seen_mask.isMajority(hashgraph)) {
                _witness = new Witness2(hashgraph);
            }
        }
        //    }
    }

    version (none) protected ~this() {
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
                assert(_order is long.init || (_order - _mother._order > 0));
            }
            if (_father) {
                pragma(msg, "fixme(bbh) this test should be reimplemented once new witness def works");
                // assert(_father._son is this, "fathers is not me");
                assert(_order is long.init || (_order - _father._order > 0));
            }
        }
    }

    override bool isFamous() const pure nothrow {
        return false;
        //return _witness && (cast(Witness2)_witness).famous;
    }
    /**
     * The witness event will point to the witness object
     * This object contains information about the voting etc. for the witness event
     */
    //version(none)
    @safe
    class Witness2 : current_event.Event.Witness {
        //protected static uint _count;
        version (none) @nogc static uint count() nothrow {
            return _count;
        }

        version (none) private {
            BitMask _vote_on_earliest_witnesses;
            BitMask _prev_strongly_seen_witnesses;
            BitMask _prev_seen_witnesses;
        }

        // BitMask[] strongly_seen_matrix;
        // BitMask strongly_seen_mask;
        //current_event.Event[] _intermediate_events;
        BitMask _intermediate_event_mask;
        BitMask _previous_strongly_seen_mask;
        uint _yes_votes;
        uint _no_votes;
        bool _decided;
        private void voteNo(const HashGraph hashgraph) pure nothrow @nogc {
            _no_votes++;
            _decided |= hashgraph.isMajority(_no_votes);
        }

        private void voteYes(const HashGraph hashgraph) pure nothrow @nogc {
            _yes_votes++;
            _decided |= hashgraph.isMajority(_yes_votes);
        }

        //bool famous;
        /**
         * Contsruct a witness of an event
         * Params:
         *   owner_event = the event which is voted to be a witness
         *   seeing_witness_in_previous_round_mask = The witness seen from this event to the previous witness.
         */
        this(HashGraph hashgraph) nothrow
        in (hashgraph.graphtype == 2)
        do {
            auto witness_event = this.outer;
            super(witness_event, hashgraph.node_size);

            witness_event._witness = this;
            if (witness_event.father_witness_is_leading) {
                _previous_strongly_seen_mask = (cast(Event2)(witness_event._mother))._intermediate_seen_mask |
                    (
                            cast(Witness2)(_father._round._events[_father.node_id]._witness))
                    ._previous_strongly_seen_mask;

            }
            else {
                //if (_mother) {
                _previous_strongly_seen_mask = witness_event._intermediate_seen_mask.dup;
            }
            //_intermediate_events.length = hashgraph.node_size;
            _intermediate_event_mask[node_id] = true;

            witness_event._intermediate_seen_mask.clear;
            witness_event._intermediate_event = false;
            witness_event._witness_seen_mask.clear;
            witness_event._witness_seen_mask[witness_event.node_id] = true;
        }

        bool hasVoted() const pure nothrow {
            return this.outer._round !is null;
        }

        void vote(HashGraph hashgraph) nothrow
        in (!hasVoted, "This witness has already voted")
        do {
            auto witness_event = this.outer;
            hashgraph._rounds.set_round(witness_event);
            if (witness_event.round.previous) {
                auto previous_witness_events = witness_event._round.previous._events;
                foreach (n; 0 .. hashgraph.node_size) {
                    auto previous_witness_event = previous_witness_events[n];
                    if (previous_witness_event) {
                        auto vote_for_witness = cast(Witness2)(previous_witness_event._witness);
                        const seen_strongly = _previous_strongly_seen_mask[n];
                        if (seen_strongly) {
                            vote_for_witness.voteYes(hashgraph);
                        }
                        else {
                            vote_for_witness.voteNo(hashgraph);
                        }
                        current_event.Event.callbacks.connect(previous_witness_event);
                    }
                }
            }
        }
    }

    bool father_witness_is_leading() const pure nothrow {
        return _father &&
            higher(_father._round.number, _mother._round.number) &&
            _father._round._events[_father.node_id];
    }

    bool calc_strongly_seen2(HashGraph hashgraph) const pure nothrow
    in (_father, "Calculation of strongly seen only makes sense if we have a father")
    in (hashgraph.graphtype == 2)
    do {
        if (father_witness_is_leading) {
            return true;
        }
        const majority_intermediate_seen = isMajority(_intermediate_seen_mask, hashgraph);
        if (majority_intermediate_seen) {
            const vote_strongly_seen = _mother._round
                ._events
                .filter!(e => e !is null)
                .map!(e => cast(Witness2) e._witness)
                .map!(w => w._intermediate_event_mask[node_id]) //.map!(event_seeing => event_seeing !is null)
                .count;
            return isMajority(vote_strongly_seen, hashgraph.node_size);
        }
        return false;
    }

    version (none) private void calc_witness_seen() pure nothrow {
        _witness_seen_mask[node_id] = true;
        if (_mother) {
            _witness_seen_mask |= (cast(Event2) _mother)._witness_seen_mask;
        }
        if (_father) {
            _witness_seen_mask |= (cast(Event2) _father)._witness_seen_mask;
        }
    }

    version (none) static EventMonitorCallbacks callbacks;

    // The altitude increases by one from mother to daughter
    version (none) immutable(EventPackage*) event_package;

    /**
  * The rounds see forward from this event
  * Returns:  round seen mask
  */
    version (none) const(BitMask) round_seen_mask() const pure nothrow @nogc {
        return _round_seen_mask;
    }

    version (none) {
        package {
            Round _round; /// The where the event has been created
            version (none) BitMask _round_received_mask; /// Voting mask for the received rounds
        }
        protected {
            Round _round_received; /// The round in which the event has been voted to be received
        }
    }
    version (none) invariant {
        if (_round_received !is null && _round_received.number > 1 && _round_received
                .previous !is null) {

            assert(_round_received.number == _round_received.previous.number + 1, format("Round was not added by 1: current: %s previous %s", _round_received
                    .number, _round_received.previous.number));
        }
    }

    /**
     * Attach the mother round to this event
     * Params:
     *   hashgraph = the graph which produces this event
     */
    version (none) package void attach_round(HashGraph2 hashgraph) pure nothrow {
        if (!_round) {
            _round = _mother._round;
        }
    }

    //immutable uint id;

    /**
    *  Makes the event a witness  
    */
    override void witness_event(HashGraph hashgraph) nothrow
    in (!_witness, "Witness has already been set")
    out {
        assert(_witness, "Witness should be set");
    }
    do {
        new Witness2(hashgraph);
        //_youngest_son_ancestors = new Event2[hashgraph.node_size];
        //_youngest_son_ancestors[node_id] = this;
    }

    //immutable size_t node_id; /// Node number of the event

    version (none) void initializeOrder() pure nothrow @nogc {
        if (order is long.init) {
            _order = -1;
        }
    }

    /**
      * Connect the event to the hashgraph
      * Params:
      *   hashgraph = event owner 
      */
    override void connect(HashGraph hashgraph)
    in {
        assert(hashgraph.areWeInGraph);
        assert(hashgraph.graphtype == 2);
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
                current_event.Event.check(this.altitude - _mother.altitude is 1,
                        ConsensusFailCode.EVENT_ALTITUDE);
                current_event.Event.check(channel == _mother.channel,
                        ConsensusFailCode.EVENT_MOTHER_CHANNEL);
            }
            hashgraph.front_seat(this);
           /*
            if (_witness && !(cast(Witness2)_witness).hasVoted) {
                (cast(Witness2)_witness).vote(hashgraph);
            }
            */
            current_event.Event.callbacks.connect(this);
            hashgraph.refinement.payload(event_package);
        }

        _mother = hashgraph.register(event_package.event_body.mother);
        if (!_mother) {
            if (!isEva && !hashgraph.joining && !hashgraph.rounds.isEventInLastDecidedRound(this)) {
                check(false, ConsensusFailCode.EVENT_MOTHER_LESS);
            }
            //   calc_strongly_seen(hashgraph);
            return;
        }

        check(!_mother._daughter, ConsensusFailCode.EVENT_MOTHER_FORK);
        _mother._daughter = this;
        _father = hashgraph.register(event_package.event_body.father);
        _order = ((_father && higher(_father.order, _mother.order)) ? _father.order : _mother.order) + 1;
        _witness_seen_mask |= (cast(Event2) _mother)._witness_seen_mask;
        _intermediate_seen_mask |= (cast(Event2) _mother)._intermediate_seen_mask;
        //hashgraph._rounds._round(this);
        if (_father) {
            assert(cast(Event2) _father !is null);
            check(!_father._son, ConsensusFailCode.EVENT_FATHER_FORK);
            _father._son = this;
            BitMask new_witness_seen;
            if (_father._round.number == _mother._round.number) {
                _witness_seen_mask |= (cast(Event2) _father)._witness_seen_mask;
                _intermediate_seen_mask |= (cast(Event2) _father)._intermediate_seen_mask;
                new_witness_seen = (cast(Event2) _father)._witness_seen_mask - (cast(Event2) _mother)
                    ._witness_seen_mask;
            }
            else {
                //_witness_seen_mask = (cast(Event2) _mother)._witness_seen_mask.dup;
                //_intermediate_seen_mask = (cast(Event2) _mother)._intermediate_seen_mask.dup;
                new_witness_seen = _witness_seen_mask;
            }
            (() @trusted => writefln("new_witness_seen=%5s  %s", new_witness_seen, new_witness_seen[]))();

            if (!new_witness_seen[].empty) {
                _intermediate_event = true;
                _intermediate_seen_mask[node_id] = true;
                auto max_round = maxRound;
                new_witness_seen[]
                    .filter!((n) => max_round._events[n]!is null)
                    .map!((n) => cast(Witness2)(max_round._events[n]._witness))
                    .filter!((witness) => witness._intermediate_event_mask[node_id])
                    .each!((witness) => witness._intermediate_event_mask[node_id] = true);
            }
            const strongly_seen = calc_strongly_seen2(hashgraph);
            if (strongly_seen) {
                 auto witness = new Witness2(hashgraph);
                witness.vote(hashgraph);
                return;
            }
        }
        hashgraph._rounds.set_round(this);
    }

    Round maxRound() nothrow {
        if (_round) {
            return _round;
        }
        if (_father && higher(_father._round.number, _mother._round.number)) {
            return _father._round;
        }
        return _mother._round;
    }

    override BitMask calc_strongly_seen_nodes(const HashGraph hashgraph) {
        assert(hashgraph.graphtype == 2);
        auto see_through_matrix = _youngest_son_ancestors
            .filter!(e => e !is null && e.round is round)
            .map!(e => e._youngest_son_ancestors
                    .map!(e => e !is null && e.round is round));

        scope strongly_seen_votes = new size_t[hashgraph.node_size];
        see_through_matrix.each!(row => row.enumerate.each!(
                elm => strongly_seen_votes[elm.index] += elm.value));
        return BitMask(strongly_seen_votes.map!(votes => hashgraph.isMajority(votes)));
    }

    override void calc_youngest_son_ancestors(const HashGraph hashgraph) {
        assert(hashgraph.graphtype == 2);
        if (!_father) {
            _youngest_son_ancestors = _mother._youngest_son_ancestors;
            return;
        }
        _youngest_son_ancestors = _mother._youngest_son_ancestors.dup();
        _youngest_son_ancestors[node_id] = this;
        iota(hashgraph.node_size)
            .filter!(n => _father._youngest_son_ancestors[n]!is null)
            .filter!(n => _youngest_son_ancestors[n] is null || _father._youngest_son_ancestors[n]
            .order > _youngest_son_ancestors[n].order)
            .each!(n => _youngest_son_ancestors[n] = _father._youngest_son_ancestors[n]);
    }

    override void calc_vote(HashGraph hashgraph, size_t vote_node_id) {
        assert(hashgraph.graphtype == 2);
        Round voting_round = hashgraph._rounds.voting_round_per_node[vote_node_id];
        auto voting_event = voting_round._events[vote_node_id];

        if (!higher(round.number, voting_round.number)) {
            return;
        }
        if (voting_round.number + 1 == round.number) {
            _witness._vote_on_earliest_witnesses[vote_node_id] = _witness
                ._prev_seen_witnesses[vote_node_id];
            return;
        }
        if (voting_event is null) {
            hashgraph._rounds.vote(hashgraph, vote_node_id);
            return;
        }
        auto votes = _witness._prev_strongly_seen_witnesses[].map!(
                i => round.previous.events[i]._witness._vote_on_earliest_witnesses[vote_node_id]);
        const yes_votes = votes.count;
        const no_votes = hashgraph.node_size - yes_votes;
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
    version (none) final package void disconnect(HashGraph hashgraph) nothrow @trusted
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

    override const bool sees(current_event.Event b) pure {

        if (_youngest_son_ancestors[b.node_id] is null) {
            return false;
        }
        if (!higher(b.order, _youngest_son_ancestors[b.node_id].order)) {
            return true;
        }
        if (node_id == b.node_id && !higher(b.order, order)) {
            return true;
        }

        pragma(msg, "why is pseudotime used for calculating see through candidates?");
        auto see_through_candidates = b[].retro
            .until!(e => e.pseudo_time_counter != b.pseudo_time_counter)
            .filter!(e => e._son)
            .map!(e => e._son);

        foreach (e; see_through_candidates) {
            if (_youngest_son_ancestors[e.node_id] is null) {
                continue;
            }
            if (!higher(e.order, _youngest_son_ancestors[e.node_id].order)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Mother event
     * Throws: EventException if the mother has been grounded
     * Returns: mother event 
     */
    version (none) final const(Event) mother() const pure {
        Event.check(!isGrounded, ConsensusFailCode.EVENT_MOTHER_GROUNDED);
        return _mother;
    }

    /**
     * Mother event
     * Throws: EventException if the mother has been grounded
     * Returns: mother event 
     */
    version (none) final const(Event) father() const pure {
        Event.check(!isGrounded, ConsensusFailCode.EVENT_FATHER_GROUNDED);
        return _father;
    }

    override void round_received(Round round_received) nothrow {
        _round_received = round_received;
    }

    version (none) @nogc pure nothrow const final {
        /**
     * The received round for this event
     * Returns: received round
     */
        const(Round) round_received() {
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
          * Returns: true if the event is owned
          */
        bool nodeOwner() const pure nothrow @nogc {
            return node_id is 0;
        }

        /**
         * Gets the event order number 
         * Returns: order
         */
        long order() const pure nothrow @nogc {
            return _order;
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

    version (none) @nogc
    package Range!false opSlice() pure nothrow {
        return Range!false(this);
    }

    version (none) @nogc
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

    version (none) {
        static assert(isInputRange!(Range!true));
        static assert(isForwardRange!(Range!true));
        static assert(isBidirectionalRange!(Range!true));
    }
}
