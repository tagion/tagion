module tagion.hashgraph.Event;

//import std.stdio;

import std.datetime; // Date, DateTime
import std.exception : assumeWontThrow;
import std.conv;

import std.format;
import std.typecons;
import std.traits : Unqual, ReturnType;
import std.array : array;

import std.algorithm.sorting : sort;
import std.algorithm.iteration : map, each, filter, cache, fold, joiner;
import std.algorithm.searching : count, any, all, until;
import std.range.primitives : walkLength, isInputRange, isForwardRange, isBidirectionalRange;
import std.range : enumerate, tee;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;

import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;

import tagion.basic.Basic : this_dot, basename, Pubkey, Buffer, EnumText, buf_idup;
import tagion.Keywords : Keywords;

import tagion.logger.Logger;
import tagion.hashgraph.HashGraphBasic : isMajority, isAllVotes, EventBody, EventPackage, EvaPayload, Tides, EventMonitorCallbacks;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.utils.BitMask : BitMask;

/// check function used in the Event package
// Returns the highest altitude
@safe @nogc
int highest(int a, int b) pure nothrow {
    if (higher(a, b)) {
        return a;
    }
    else {
        return b;
    }
}

// Is a higher or equal to b
@safe @nogc
bool higher(int a, int b) pure nothrow {
    return a - b > 0;
}

@safe
unittest { // Test of the altitude measure function
    int x = int.max - 10;
    int y = x + 20;
    assert(x > 0);
    assert(y < 0);
    assert(highest(x, y) == y);
    assert(higher(y, x));
    assert(!higher(x, x));
}

@safe
class Round {
    //    bool erased;
    enum uint total_limit = 3;
    enum int coin_round_limit = 10;
    private Round _previous;
    private Round _next;
    private bool _decided;
    immutable int number;

    private Event[] _events;

    @nogc bool lessOrEqual(const Round rhs) pure const nothrow {
        return (number - rhs.number) <= 0;
    }

    @nogc const(uint) node_size() pure const nothrow {
        return cast(uint) _events.length;
    }

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

    @nogc
    const(Event[]) events() const pure nothrow {
        return _events;
    }

    //@nogc
    package void add(Event event) pure nothrow
    in {
        assert(_events[event.node_id] is null, "Event at node_id " ~ event.node_id.to!string ~ " should only be added once");
    }
    do {
        _events[event.node_id] = event;
        event._round = this;
    }

    @nogc
    bool empty() const pure nothrow {
        return !_events.any!((e) => e !is null);
    }

    @nogc
    size_t event_count() const pure nothrow {
        return _events.count!((e) => e !is null);
    }

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

    @trusted
    private void scrap(HashGraph hashgraph)
    in {
        assert(!_previous, "Round can not be scrapped due that a previous round still exists");
    }
    // out {
    //     assert(_events.all!((e) => e is null));
    // }
    do {
        uint count;
        void scrap_events(Event e) {
            if (e !is null) {
                count++;
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

    @nogc bool decided() const pure nothrow {
        return _decided;
    }

    @nogc
    inout(Event) event(const size_t node_id) pure inout {
        return _events[node_id];
    }

    @nogc
    package inout(Round) previous() inout pure nothrow {
        return _previous;
    }

    invariant {
        assert(!_previous || (_previous.number + 1 is number));
        assert(!_next || (_next.number - 1 is number));
    }

    struct Rounder {
        Round last_round;
        Round last_decided_round;
        HashGraph hashgraph;

        @disable this();

        this(HashGraph hashgraph) pure nothrow {
            this.hashgraph = hashgraph;
            last_round = new Round(null, hashgraph.node_size);
            //            last_decided_round._decided=true;
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

        @nogc
        size_t length() const pure nothrow {
            return this[].walkLength;
        }

        uint node_size() const pure nothrow
        in {
            assert(last_round, "Last round must be initialized before this function is called");
        }
        do {
            return cast(uint)(last_round._events.length);

        }

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
                if (Event.callbacks) {
                    Event.callbacks.round_seen(e);
                }
            }
        }

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

        @nogc
        int coin_round_distance() pure const nothrow {
            return last_round.number - last_decided_round.number;
        }

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

        @nogc
        bool check_decided_round_limit() pure const nothrow {
            return cached_decided_count > total_limit;
        }

        private void collect_received_round(Round r, HashGraph hashgraph) {
            uint mark_received_iteration_count;
            uint order_compare_iteration_count;
            uint epoch_events_count;
            // uint count;
            scope (success) {
                hashgraph.mark_received_statistic(mark_received_iteration_count);
                hashgraph.order_compare_statistic(order_compare_iteration_count);
                hashgraph.epoch_events_statistic(epoch_events_count);
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

            auto event_filter = r._events
                .filter!((e) => (e !is null))
                .map!((ref e) => e[]
                        .until!((e) => (e._round_received !is null))
                        .filter!((e) => (e._round_received_mask.isMajority(hashgraph))))
                .joiner
                .tee!((e) => e._round_received = r)
                .map!((e) => e);

            bool order_less(const Event a, const Event b) @safe {
                order_compare_iteration_count++;
                if (a.received_order is b.received_order) {
                    if (a._mother && b._mother) {
                        return order_less(a._mother, b._mother);
                    }
                    if (a._father && b._father) {
                        return order_less(a._father, b._father);
                    }
                    if (!a._father) {
                        return false;
                    }
                    if (b._father) {
                        return true;
                    }

                    bool rare_less(Buffer a, Buffer b) {
                        const ab = hashgraph.hirpc.net.calcHash(a ~ b);
                        const ba = hashgraph.hirpc.net.calcHash(b ~ a);
                        // const A = (BitMask(ab).count);
                        // const B = (BitMask(ba).count);
                        // if (A is B) {
                        //     return rare_less(ab, ba);
                        // }
                        return ab < ba;
                    }

                    return rare_less(a.fingerprint, b.fingerprint);
                }
                return a.received_order < b.received_order;
            }

            // Collect and sort all events
            sdt_t[] times;
            auto event_collection = event_filter
                .tee!((e) => times ~= e.event_body.time)
                .filter!((e) => !e.event_body.payload.empty)
                .array
                .sort!((a, b) => order_less(a, b))
                .release;
            times.sort;
            const mid = times.length / 2 + (times.length % 1);
            hashgraph.epoch(event_collection, times[mid], r);
        }

        void check_decided_round(HashGraph hashgraph) @trusted {
            auto round_to_be_decided = last_decided_round._next;

            if (hashgraph.can_round_be_decided(round_to_be_decided)) {
                const votes_mask = BitMask(round_to_be_decided.events
                        .filter!((e) => (e) && !hashgraph.excluded_nodes_mask[e.node_id])
                        .map!((e) => e.node_id));
                if (votes_mask.isMajority(hashgraph)) {
                    const round_decided = votes_mask[]
                        .all!((vote_node_id) => round_to_be_decided._events[vote_node_id]._witness.famous(
                                hashgraph));
                    if (round_decided) {
                        collect_received_round(round_to_be_decided, hashgraph);
                        round_to_be_decided._decided = true;
                        last_decided_round = round_to_be_decided;
                        check_decided_round(hashgraph);

                    }
                }
            }
        }

        @nogc
        package Range!false opSlice() pure nothrow {
            return Range!false(last_round);
        }

        @nogc
        Range!true opSlice() const pure nothrow {
            return Range!true(last_round);
        }

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

@safe
class Event {
    package static bool scrapping;

    import tagion.basic.ConsensusExceptions;

    alias check = Check!EventConsensusException;
    protected static uint _count;
    @nogc
    static uint count() nothrow {
        return _count;
    }

    package this(
            immutable(EventPackage)* epack,
            HashGraph hashgraph,
    ) {
        event_package = epack;
        this.node_id = hashgraph.getNode(channel).node_id;
        this.id = hashgraph.next_event_id;
        _witness_mask[node_id] = true;
        _count++;

        if (Event.callbacks) {
            Event.callbacks.create(this);
        }

    }

    ~this() {
        _count--;
    }

    invariant {
        if (!scrapping) {
            if (_mother) {
                assert(!_witness_mask[].empty);
                assert(_mother._daughter is this);
                assert(
                        event_package.event_body.altitude - _mother
                        .event_package.event_body.altitude is 1);
                assert(_received_order is int.init || (_received_order - _mother._received_order > 0));
            }
            if (_father) {
                assert(_father._son is this);
                assert(_received_order is int.init || (_received_order - _father._received_order > 0));
            }
        }
    }

    @safe
    class Witness {
        protected static uint _count;
        @nogc static uint count() nothrow {
            return _count;
        }

        private {
            immutable(BitMask) _seeing_witness_in_previous_round_mask; /// The marks resulting to this witness
            BitMask _strong_seeing_mask;
            bool _famous;
        }

        @trusted
        this(Event owner_event, ref const(BitMask) seeing_witness_in_previous_round_mask) nothrow
        in {
            assert(owner_event);
        }
        do {
            _seeing_witness_in_previous_round_mask = cast(immutable) seeing_witness_in_previous_round_mask
                .dup;
            _count++;
        }

        ~this() {
            _count--;
        }

        pure nothrow final {
            @nogc
            const(BitMask) strong_seeing_mask() const {
                return _strong_seeing_mask;
            }

            @nogc
            ref const(BitMask) round_seen_mask() const {
                return _seeing_witness_in_previous_round_mask;
            }

            bool famous() const {
                return _famous;
            }

            @nogc
            private bool famous(const HashGraph hashgraph) {
                if (!_famous) {
                    _famous = _strong_seeing_mask.isMajority(hashgraph);
                }
                return _famous;
            }
        }
    }

    static EventMonitorCallbacks callbacks;

    // The altitude increases by one from mother to daughter
    immutable(EventPackage*) event_package;

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
        BitMask _witness_mask;
        BitMask _round_seen_mask;
    }

    private {
        Round _round;
        Round _round_received;
        BitMask _round_received_mask;
    }

    package void attach_round(HashGraph hashgraph) pure nothrow {
        if (!_round) {
            _round = _mother._round;
        }
    }

    immutable uint id;

    /**
       This function is
    */
    package void witness_event() nothrow
    in {
        assert(!_witness);
    }
    do {
        BitMask round_mask;
        _witness = new Witness(this, round_mask);
    }

    immutable size_t node_id;

    private void received_order(ref uint iteration_count) pure nothrow {
        if (isFatherLess) {
            if (_mother) {
                if (_mother._received_order is int.init) {
                    _mother.received_order(iteration_count);
                }
                _received_order = expected_order;
            }
        }
        else if (_received_order is int.init) {
            _received_order = expected_order;
            if (_received_order !is int.init) {
                received_order(iteration_count);
            }
        }
        else {
            const expected = expected_order;
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
                _received_order = expected_order;
                if (_son) {
                    _son.received_order(iteration_count);
                }
                if (_daughter) {
                    _daughter.received_order(iteration_count);
                }

            }
        }
    }

    private void strong_seeing(HashGraph hashgraph) pure nothrow {
        uint strong_seeing_interation_count;
        scope (exit) {
            hashgraph.strong_seeing_statistic(strong_seeing_interation_count);
        }
        void local_strong_seeing(Round r, const BitMask seeing_mask) pure nothrow @trusted {
            strong_seeing_interation_count++;
            if (r && r._previous && !r._previous.decided) {
                BitMask next_seeing_mask;
                foreach (e; r._events) {
                    if (e && seeing_mask[e.node_id]) {
                        next_seeing_mask |= e._witness.round_seen_mask;
                        if (next_seeing_mask.isAllVotes(hashgraph)) {
                            break;
                        }
                    }
                }
                local_strong_seeing(r._previous, next_seeing_mask);
                if (next_seeing_mask.isMajority(hashgraph)) {
                    r._previous
                        ._events
                        .filter!((e) => (e) && next_seeing_mask[e.node_id])
                        .each!((e) => e._witness._strong_seeing_mask[node_id] = true);
                }
            }
        }

        local_strong_seeing(_round._previous, _witness.round_seen_mask);
    }

    // +++
    private const(BitMask) calc_witness_mask(HashGraph hashgraph) nothrow
    in {
        assert(!_mother._witness_mask[].empty);
    }
    do {
        uint iterative_witness_search_count;
        scope (exit) {
            hashgraph.witness_search_statistic(iterative_witness_search_count);
        }
        const(BitMask) local_calc_witness_mask(const Event e, const BitMask voting_mask, const BitMask marker_mask) nothrow @safe {
            iterative_witness_search_count++;
            if (e && e._round && !marker_mask[e.node_id]) {
                BitMask result = voting_mask.dup;
                if (e._round.number == _round.number) {
                    result[e.node_id] = true;
                    const collecting_voting_mask = e._witness_mask & ~result;
                    if (!collecting_voting_mask[].empty) {
                        result |= local_calc_witness_mask(e._father, result, marker_mask + e
                                .node_id);
                        result |= local_calc_witness_mask(e._mother, result, marker_mask);
                    }
                }
                else if (e._round.number > _round.number) {
                    const event_round = e._round.events[e.node_id];
                    if (event_round) {
                        result |= event_round._witness.round_seen_mask;
                        const collecting_voting_mask = e._witness_mask & ~result;
                        if (!collecting_voting_mask[].empty) {
                            result |= local_calc_witness_mask(event_round, result, marker_mask);
                            result |= local_calc_witness_mask(e._father, result, marker_mask + e
                                    .node_id);
                        }
                    }
                }
                return result;
            }
            return voting_mask;
        }

        return local_calc_witness_mask(this, BitMask(), BitMask());
    }

    package final void connect(HashGraph hashgraph)
    in {
        assert(hashgraph.areWeInGraph);

    }
    out {
        assert(event_package.event_body.mother && _mother || !_mother);
        assert(event_package.event_body.father && _father || !_father);
    }
    do {
        if (!connected) {
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
                attach_round(hashgraph);
                _witness_mask = _mother._witness_mask;
                if (_father) {
                    check(!_father._son, ConsensusFailCode.EVENT_FATHER_FORK);
                    _father._son = this;
                    _witness_mask |= _father._witness_mask;
                }
                if (callbacks) {
                    callbacks.round(this);
                }
                uint received_order_iteration_count;
                received_order(received_order_iteration_count);
                hashgraph.received_order_statistic(received_order_iteration_count);
                auto witness_seen_mask = calc_witness_mask(hashgraph);
                if (witness_seen_mask.isMajority(hashgraph)) {
                    hashgraph._rounds.next_round(this);
                    _witness = new Witness(this, witness_seen_mask);

                    strong_seeing(hashgraph);
                    hashgraph._rounds.check_decided_round(hashgraph);
                    _witness_mask.clear;
                    _witness_mask[node_id] = true;
                    if (callbacks) {
                        callbacks.witness(this);
                    }

                }

            }
            else if (!isEva) {
                check(false, ConsensusFailCode.EVENT_MOTHER_LESS);
            }
        }
    }

    // +++
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

    final const(Event) mother() const pure {
        Event.check(!isGrounded, ConsensusFailCode.EVENT_MOTHER_GROUNDED);
        return _mother;
    }

    final const(Event) father() const pure {
        Event.check(!isGrounded, ConsensusFailCode.EVENT_FATHER_GROUNDED);
        return _father;
    }

    @nogc pure nothrow const final {
        ref const(EventBody) event_body() {
            return event_package.event_body;
        }

        const(Round) round_received() {
            return _round_received;
        }

        immutable(Pubkey) channel() {
            return event_package.pubkey;
        }

        const(BitMask) round_received_mask() {
            return _round_received_mask;
        }

        bool isFront() {
            return _daughter is null;
        }

        bool hasRound() {
            return (_round !is null);
        }

        const(Round) round()
        out (result) {
            assert(result, "Round must be set before this function is called");
        }
        do {
            return _round;
        }

        const(BitMask) witness_mask() {
            return _witness_mask;
        }

        const(Witness) witness() {
            return _witness;
        }

        immutable(int) altitude() {
            return event_package.event_body.altitude;
        }

        int expected_order() {
            const m = (_mother) ? _mother._received_order : int.init;
            const f = (_father) ? _father._received_order : int.init;
            int result = (m - f > 0) ? m : f;
            result++;
            result = (result is int.init) ? int.init + 1 : result;
            return result;
        }

        bool nodeOwner() {
            return node_id is 0;
        }

        int received_order()
        in {
            assert(isEva || (_received_order !is int.init), "The received order of this event has not been defined");
        }
        do {
            return _received_order;
        }

        bool connected() {
            return (_mother !is null);
        }

        const(Event) daughter() {
            return _daughter;
        }

        const(Event) son() {
            return _son;
        }

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
