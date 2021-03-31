module tagion.hashgraph.Event;

import std.datetime;   // Date, DateTime
import std.exception : assumeWontThrow;
import std.conv;

import std.format;
import std.typecons;
import std.traits : Unqual, ReturnType;
import std.range : enumerate;
import std.array : array;

import std.algorithm.sorting : sort;
import std.algorithm.iteration : map, each, filter, cache, fold, joiner;
import std.algorithm.searching : count, any, all, until;
import std.range.primitives : walkLength, isInputRange, isForwardRange, isBidirectionalRange;
import std.range : chain;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord ;

import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;

import tagion.basic.Basic : this_dot, basename, Pubkey, Buffer, bitarray_clear, bitarray_change, EnumText, buf_idup;
import tagion.Keywords : Keywords;

import tagion.basic.Logger;
import tagion.hashgraph.HashGraphBasic : isMajority, isAllVotes, EventBody, EventPackage, EvaPayload, Tides, EventMonitorCallbacks, EventScriptCallbacks;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.utils.BitMask : BitMask;

/// check function used in the Event package
// Returns the highest altitude
@safe @nogc
int highest(int a, int b) pure nothrow {
    if ( higher(a,b) ) {
        return a;
    }
    else {
        return b;
    }
}

// Is a higher or equal to b
@safe @nogc
bool higher(int a, int b) pure nothrow {
    return a-b > 0;
}

@safe @nogc
bool lower(int a, int b) pure nothrow {
    return a-b < 0;
}

@safe
unittest { // Test of the altitude measure function
    int x=int.max-10;
    int y=x+20;
    assert(x>0);
    assert(y<0);
    assert(highest(x,y) == y);
    assert(higher(y,x));
    assert(lower(x,y));
    assert(!lower(x,x));
    assert(!higher(x,x));
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
        return cast(uint)_events.length;
    }

    private this(Round previous, const size_t node_size) pure nothrow {
        if (previous) {
            number=previous.number+1;
            previous._next = this;
            _previous=previous;
        }
        else {
            number=-1;
        }
        _events=new Event[node_size];
    }

    const(Event[]) events() const pure nothrow {
        return _events;
    }

    //@nogc
    package void add(Event event) pure nothrow
    in {
        assert(_events[event.node_id] is null, "Event at node_id "~event.node_id.to!string~" should only be added once");
    }
    do {
        _events[event.node_id]=event;
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
        if ( !event.isEva && _events[event.node_id] ) {
            _events[event.node_id]=null;
        }
    }

    // void _scrap_events(Event e) {
    //     if (e !is null) {
    //         _scrap_events(e._mother);
    //         //e._xxx;
    //         // writefln("(%d:%d) %s", e.id, e.node_id, e.isEva);
    //         //e.disconnect(hashgraph);
    //         //e.destroy;
    //     }
    // }

    @trusted
    private void scrap(HashGraph hashgraph)
        in {
            //assert(!_previous, "Round can not be scrapped due that a previous round still exists");
        }
    out {
        //assert(_events.all!((e) => e is null));
    }
    do {
        //import std.stdio;
        //writefln("number=%d", number);
        // writefln("Before _events=%s", _events.map!((e) => e is null));
        uint count;
        void scrap_events(Event e) {
            if (e !is null) {
                count++;
                scrap_events(e._mother);
                e.disconnect(hashgraph);
                e.destroy;
            }
        }
        foreach(node_id, e; _events) {
            scrap_events(e);
        }
        //erased = true;
        _next._previous = null;
        _next = null;
        // writefln("After _events=%s", _events.map!((e) => e is null));
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
        // void check_round_order(const Round r, const Round p) pure {
        //     if ( ( r !is null) && ( p !is null ) ) {
        //         assert( (r.number-p.number) == 1,
        //             format("Consecutive round-numbers has to increase by one (rounds %d and %d)", r.number, p.number));
        //         if ( r._decided ) {
        //              assert( p._decided, "If a higher round is decided all rounds below must be decided");
        //         }
        //         check_round_order(r._previous, p._previous);
        //     }
        // }
        // check_round_order(this, _previous);
        assert(!_previous || (_previous.number+1 is number));
        assert(!_next || (_next.number-1 is number));

    }


    struct Rounder {
        Round _last_round;
        Round last_decided_round;
        HashGraph hashgraph;

        @disable this();

        this(HashGraph hashgraph) pure nothrow {
            this.hashgraph=hashgraph;
            last_decided_round = _last_round = new Round(null, hashgraph.node_size);
            last_decided_round._decided=true;
        }

        void dustman() {
            //if (!hashgraph.print_flag) return;
            void local_dustman(Round r) @trusted {
                if (r !is null) {
                    local_dustman(r._previous);
                    r.scrap(hashgraph);
                    //r.destroy;
                }
            }
            Event.scrapping=true;
            scope(exit) {
                Event.scrapping=false;
            }
            int depth=hashgraph.scrap_depth;
            for(Round r=last_decided_round; r !is null; r=r._previous) {
                depth--;
                if (depth < 0) {
                    local_dustman(r);
                    break;
                }
            }
        }

        @nogc
        inout(Round) last_round() inout pure nothrow {
            return _last_round;
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
                //assert(e._round is null, "Round has already been added");
            }
        out {
            assert(e._round !is null);
        }
        do {
            if (!e.isFatherLess) {
                scope (exit) {
                    e._round.add(e);
                }
                if (e._round && e._round._next) {
                    e._round = e._round._next;
                }
                else {
                    e._round = new Round(last_round, hashgraph.node_size);
                    _last_round = e._round;
                    if (Event.callbacks) {
                        Event.callbacks.round_seen(e);
                    }
                }

            }
        }

        @nogc
        bool decided(const Round test_round) pure const nothrow {
            bool _decided(const Round r) pure nothrow  {
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
            uint _cached_decided_count(const Round r, const uint i=0) pure nothrow {
                if (r) {
                    return _cached_decided_count(r._previous, i+1);
                }
                return i;
            }
            return _cached_decided_count(last_round);
        }

        @nogc
        bool check_decided_round_limit() pure const nothrow {
            return cached_decided_count > total_limit;
        }

        private const(Event[]) collect_received_round(Round r, HashGraph hashgraph) {
            uint mark_received_iteration_count;
            uint order_compare_iteration_count;
            uint epoch_events_count;
            scope(success) {
                hashgraph.mark_received_statistic(mark_received_iteration_count);
                hashgraph.order_compare_statistic(order_compare_iteration_count);
                hashgraph.epoch_events_statistic(epoch_events_count);
            }
            // Clean the round_seen_masks which has been assign to a round_received
            r._events
                .filter!((e) => (e !is null))
                .each!((e) => e[]
                    .until!((e) => (e._round_received !is null))
                    .each!((ref e) => e._round_received_mask.clear)); //{pragma(msg, (typeof(e))); true;});

            void mark_received_events(const size_t voting_node_id, Event e, const BitMask marker_mask) {
                mark_received_iteration_count++;
                if ((e) && (!e._round_received) && !e._round_received_mask[voting_node_id] && !marker_mask[e.node_id] ) {
                    e._round_received_mask[voting_node_id]=true;
                    mark_received_events(voting_node_id, e._father, marker_mask+e.node_id);
                    mark_received_events(voting_node_id, e._mother, marker_mask);
                }
            }
            // Marks all the event below round r
            r._events
                .filter!((e) => (e !is null))
                .each!((ref e) => mark_received_events(e.node_id, e, BitMask()));

            auto event_filter = r._events
                .filter!((e) => (e !is null))
                .map!((ref e) => e[]
                    .until!((e) => (e._round_received !is null))
                    .filter!((e) => (e._round_received_mask.isMajority(hashgraph))));

            // Sets all the selected event to the round r
            event_filter
                .joiner
                .each!((ref e) => e._round_received = r);
            bool order_less(const Event a, const Event b) @safe
                in {
                    assert(a._round_received is b._round_received);
                }
            do {
                order_compare_iteration_count++;
                if (a.received_order is b.received_order) {
                    if (a._mother && b._mother &&
                        a._mother._round_received is a._round_received &&
                        b._mother._round_received is a._round_received) {
                        return order_less(a._mother, b._mother);
                    }
                    if (a._father && b._father &&
                        a._father._round_received is a._round_received &&
                        b._father._round_received is a._round_received) {
                        return order_less(a._father, b._father);
                    }
                    if (a._mother &&
                        a._mother._round_received is a._round_received) {
                        return false;
                    }
                    if (a._father &&
                        a._father._round_received is a._round_received) {
                        return true;
                    }

                    bool rare_less(Buffer a, Buffer b) {
                        const ab=hashgraph.hirpc.net.calcHash(a~b);
                        const ba=hashgraph.hirpc.net.calcHash(b~a);
                        const A=(BitMask(ab).count);
                        const B=(BitMask(ba).count);
                        if (A is B) {
                            return rare_less(ab, ba);
                        }
                        return A < B;
                    }
                    return rare_less(a.fingerprint, b.fingerprint);
                }
                return a.received_order < b.received_order;
            }

            // Collect and sort all events
            auto event_collection = event_filter
                .joiner
                .filter!((e) => !e.event_body.payload.empty)
                .array
                .sort!((a, b) => order_less(a,b))
                .release;

            return event_collection;
        }

        void check_decided_round(HashGraph hashgraph) @trusted {
            import std.stdio;
            auto round_to_be_decided=last_decided_round._next;
            const votes_mask=BitMask(round_to_be_decided.events
                .filter!((e) => (e) && !hashgraph.excluded_nodes_mask[e.node_id])
                .map!((e) => e.node_id));
            if (votes_mask.isMajority(hashgraph)) {
                const round_decided=votes_mask[]
                    .all!((vote_node_id) => round_to_be_decided._events[vote_node_id]._witness.famous(hashgraph));
                if (round_decided) {
                    if (hashgraph.print_flag) writefln("\tround decided %d", round_to_be_decided.number);
                    const events=collect_received_round(round_to_be_decided, hashgraph);
                    hashgraph.epoch(events, round_to_be_decided);
                    round_to_be_decided._decided=true;
                    last_decided_round=round_to_be_decided;
                    check_decided_round(hashgraph);
                }
            }
        }

        @nogc
        package Range!false opSlice() pure nothrow {
            return Range!false(_last_round);
        }

        @nogc
        Range!true opSlice() const pure nothrow {
            return Range!true(_last_round);
        }

        @nogc
        struct Range(bool CONST=true) {
            private Round round;
            @trusted
            this(const Round round) pure nothrow {
                this.round=cast(Round)round;
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

                alias back=front;

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
//    bool erased;
    package static bool scrapping;

    import tagion.basic.ConsensusExceptions;
    alias check=Check!EventConsensusException;
    //immutable size_t node_size;
    protected static uint _count;
    static uint count() nothrow {
        return _count;
    }

// FixMe: CBR 19-may-2018
// Note pubkey is redundent information
// The node_id should be enought this will be changed later
    package this(
        immutable(EventPackage)* epack,
        HashGraph hashgraph,
        ) {
	event_package=epack;
        this.node_id=hashgraph.getNode(channel).node_id;
        this.id=hashgraph.next_event_id;
        _witness_mask[node_id]=true;
        _count++;

        if ( isEva ) {
            // If the event is a Eva event the round is undefined until a daughter in generation after get a father
            BitMask round_mask;
            _witness = new Witness(this, round_mask);
        }
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
                assert(event_package.event_body.altitude - _mother.event_package.event_body.altitude is 1);
                assert(_received_order is int.init || (_received_order - _mother._received_order > 0));
            }
            if (_father) {
                assert(_father._son is this);
                assert(_received_order is int.init || (_received_order - _father._received_order > 0));
            }
        }
    }

    @nogc
    bool isInFront() const pure nothrow {
        return !_daughter;
    }

    @safe
    class Witness {
        protected static uint _count;
        @nogc static uint count() nothrow {
            return _count;
        }
        private {
            immutable(BitMask) _seeing_witness_in_previous_round_mask; /// The maks resulting to this witness
            BitMask _strong_seeing_mask;
            bool _famous;
        }

        @trusted
        this(Event owner_event, ref const(BitMask) seeing_witness_in_previous_round_mask) nothrow
        in {
            assert(owner_event);
        }
        do {
            _seeing_witness_in_previous_round_mask=cast(immutable)seeing_witness_in_previous_round_mask.dup;
            _count++;
        }

        ~this() {
            _count--;
        }

        @nogc
        const(BitMask) strong_seeing_mask() pure const nothrow {
            return _strong_seeing_mask;
        }


        @nogc
        ref const(BitMask) round_seen_mask() pure const nothrow {
            return _seeing_witness_in_previous_round_mask;
        }

        bool famous() pure const nothrow {
            return _famous;
        }

        @nogc
        private bool famous(const HashGraph hashgraph) pure nothrow {
            if (!_famous) {
                _famous=_strong_seeing_mask.isMajority(hashgraph);
            }
            return _famous;
        }

    }

//    alias Event delegate(immutable(ubyte[]) fingerprint, Event child) @safe Lookup;
    alias bool delegate(Event) @safe Assign;
    static EventMonitorCallbacks callbacks;
    static EventScriptCallbacks scriptcallbacks;

    @nogc
    immutable(Pubkey) channel() pure const nothrow {
        return event_package.pubkey;
    }

    // The altitude increases by one from mother to daughter
    immutable(EventPackage*) event_package;

    ref const(EventBody) event_body() const nothrow {
        return event_package.event_body;
    }

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
        Round  _round;
        Round  _round_received;
        BitMask _round_received_mask;
    }

    @nogc
    const(BitMask) round_received_mask() const pure nothrow {
        return _round_received_mask;
    }

    private void attach_round(HashGraph hashgraph) pure nothrow
        in {
            assert(_round is null, "Round has already been attached");
        }
    do {
        if (_mother.isFatherLess) {
            if (_father && _father._round) {
                _round = _father._round;
            }
            else {
                _round = hashgraph._rounds.last_round;
            }
            for(Event e=_mother; e !is null; e=e._mother) {
                assert(e.isFatherLess);
                e._round =_round;
            }
        }
        else {
            _round = _mother._round;
        }
    }

    immutable uint id;

    @nogc
    static bool cmp(scope const(size_t[]) a, scope const(size_t[]) b) pure nothrow
        in {
            assert(a.length == b.length);
        }
    do {
        import tagion.utils.Gene : gene_count;
        uint result;
        foreach(i, r; a) {
            result+=gene_count(r^~b[i]);
            if (result < a.length*ulong.sizeof*4) {
                return false;
            }
        }
        return true;
    }

    @nogc
    static int timeCmp(const(Event) a, const(Event) b) pure nothrow {
        immutable diff=cast(long)(b.eventbody.time) - cast(long)(a.eventbody.time);
        if ( diff < 0 ) {
            return -1;
        }
        else if ( diff > 0 ) {
            return 1;
        }
        if ( cmp(cast(immutable(size_t[]))(a.fingerprint), cast(immutable(size_t[]))(b.fingerprint)) ) {
            return -1;
        }
        return 1;
    }

    @nogc
    int opCmp(const(Event) rhs) const pure nothrow {
        immutable diff=rhs._received_order - _received_order;
        if ( diff < 0 ) {
            return -1;
        }
        else if ( diff > 0 ) {
            return 1;
        }
        if ( cmp(cast(immutable(size_t[]))(fingerprint), cast(immutable(size_t[]))(rhs.fingerprint)) ) {
            return -1;
        }
        return 1;
    }

    @nogc
    final const(Round) round_received() pure const nothrow {
        return _round_received;
    }

    @nogc
    bool isFront() pure const nothrow {
        return _daughter is null;
    }

    @nogc
    inout(Round) round() inout pure nothrow
        out(result) {
            assert(result, "Round should be defined before it is used");
        }
    do {
        return _round;
    }

    @nogc
    bool hasRound() const pure nothrow {
        return (_round !is null);
    }

    @nogc
    const(Round) round() pure const nothrow
    out(result) {
        assert(result, "Round must be set before this function is called");
    }
    do {
        return _round;
    }

    @nogc
    ref const(BitMask) witness_mask() pure const nothrow {
        return _witness_mask;
    }

    @nogc
    const(Witness) witness() pure const nothrow {
        return _witness;
    }


    @nogc
    bool strongly_seeing() const pure nothrow {
        return _witness !is null;
    }

    @trusted
    bool seeing_witness(const uint node_id) const pure
        in {
            assert(_witness, "Seeing witness can only be called from witness event");
        }
    do {
        bool result;
        if ( mother ) {
            if ( _mother.witness_mask[node_id] ) {
                result=true;
            }
            else if ( _round.lessOrEqual(_mother._round) ) {
                result=_mother._round.event(_mother.node_id).seeing_witness(node_id);
            }
        }
        else if ( father ) {
            if ( _father.witness_mask[node_id] ) {
                result=true;
            }
            else if ( _round.lessOrEqual(_father._round) ) {
                result=_father._round.event(_father.node_id).seeing_witness(node_id);
            }
        }
        return result;
    }

    @nogc
    immutable(int) altitude() const pure nothrow {
        return event_package.event_body.altitude;
    }

    immutable size_t node_id;

    @nogc
    bool nodeOwner() const pure nothrow {
        return node_id is 0;
    }

    @nogc
    int expected_order() const pure nothrow {
        const m=(_mother)?_mother._received_order:int.init;
        const f=(_father)?_father._received_order:int.init;
        int result=(m-f > 0)?m:f;
        result++;
        result=(result is int.init)?int.init+1:result;
        return result;
    }

    private void received_order(ref uint iteration_count) {
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

    private void strong_seeing(HashGraph hashgraph) @trusted {
        uint strong_seeing_interation_count;
        scope(exit) {
            hashgraph.strong_seeing_statistic(strong_seeing_interation_count);
        }
        void local_strong_seeing(Round r, const BitMask seeing_mask) @trusted {
            strong_seeing_interation_count++;
            if (r && r._previous && !r._previous.decided) {
                BitMask next_seeing_mask;
                foreach(e; r._events) {
                    if (e && seeing_mask[e.node_id]) {
                        next_seeing_mask |= e._witness.round_seen_mask;
                        if (next_seeing_mask.isAllVotes(hashgraph)) {
                            break;
                        }
                    }
                }
                local_strong_seeing(r._previous, next_seeing_mask);
                if (next_seeing_mask.isMajority(hashgraph)) {
                    r._previous._events
                        .filter!((e) => (e) && next_seeing_mask[e.node_id])
                        .each!((e) => e._witness._strong_seeing_mask[node_id]=true);
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
        scope(exit) {
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
                        result |= local_calc_witness_mask(e._father, result, marker_mask+e.node_id);
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
                            result |= local_calc_witness_mask(e._father, result, marker_mask+node_id);
                        }
                    }
                }
                return result;
            }
            return voting_mask;
        }
        return local_calc_witness_mask(this, BitMask(), BitMask());
    }


    //@trusted
    package void connect(HashGraph hashgraph)
    out {
        assert(event_package.event_body.mother && _mother || !_mother);
        assert(event_package.event_body.father && _father || !_father);
    }
    do {
        if (!connected) {
            scope(exit) {
                if (_mother) {
                    Event.check(this.altitude-_mother.altitude is 1,
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
                if ( callbacks ) {
                    callbacks.round(this);
                }
                uint received_order_iteration_count;
                received_order(received_order_iteration_count);
                hashgraph.received_order_statistic(received_order_iteration_count);
                auto witness_seen_mask = calc_witness_mask(hashgraph);
                if ( witness_seen_mask.isMajority(hashgraph) ) {
                    hashgraph._rounds.next_round(this);
                    _witness = new Witness(this, witness_seen_mask);
                    strong_seeing(hashgraph);
                    hashgraph._rounds.check_decided_round(hashgraph);
                    _witness_mask.clear;
                    _witness_mask[node_id]=true;
                    if ( callbacks) {
                        callbacks.witness(this);
                    }

                }

            }
            else if (!isEva) {
                check(false, ConsensusFailCode.EVENT_MOTHER_LESS);
            }
        }
    }

    @nogc
    int received_order() const pure nothrow
        in {
            assert(isEva || (_received_order !is int.init), "The received order of this event has not been defined");
        }
    do {
        return _received_order;
    }

// +++
    @nogc
    bool connected() const pure nothrow {
        return (_mother !is null);
    }

    @trusted
    private void disconnect(HashGraph hashgraph) {
    //     in {
    //         //assert(!_mother, "Event with a mother can not be disconnected");
    //         //  assert(!_father, "Event with a father can not be disconnected");
    //     }
    // do {
//        erased=true;
        hashgraph.eliminate(fingerprint);

        // return;
        if (_witness) {
            // import std.stdio;
            // writefln("Before remove node_id=%d %s", node_id, _round._events[node_id] !is null);
            _round.remove(this);
            // writefln("After node_id=%d %s", node_id, _round._events[node_id] !is null);
            _witness.destroy;
            _witness=null;
        }
        if (_daughter) {
            _daughter._mother = null;
        }
        if (_son) {
            _son._father = null;
        }
        _daughter=_son=null;
        //_mother=_father=null;
    }

    const(Event) mother() const pure {
        Event.check(!isGrounded, ConsensusFailCode.EVENT_MOTHER_GROUNDED);
        return _mother;
    }

    @nogc
    const(Event) father() const pure nothrow
    in {
        if ( event_package.event_body.father ) {
            if (!_father) {
                import std.stdio;
                debug assumeWontThrow(writefln("Father is dead"));
            }
            assert(_father, "Father is dead");
        }
    }
    do {
        return _father;
    }

    @nogc
    const(Event) daughter() const pure nothrow {
        return _daughter;
    }

    @nogc
    package Event daughter_raw() pure nothrow {
        return _daughter;
    }

    @nogc
    const(Event) son() const pure nothrow {
        return _son;
    }

    @nogc
    const(Document) payload() const pure nothrow {
        return event_package.event_body.payload;
    }

    @nogc
    ref const(EventBody) eventbody() const pure nothrow {
        return event_package.event_body;
    }

    //True if Event contains a payload or is the initial Event of its creator
    @nogc
    bool containPayload() const pure nothrow {
        return !payload.empty;
    }

    @nogc
    bool fatherExists() const pure nothrow {
        return event_package.event_body.father !is null;
    }

    // is true if the event does not have a mother or a father
    @nogc
    bool isEva() pure const nothrow
        out(result) {
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
    @nogc
    bool isFatherLess() pure const nothrow {
        return isEva || !isGrounded && (event_package.event_body.father is null) && _mother.isFatherLess;
    }

    @nogc
    bool hasOrder() pure const nothrow {
        return _received_order !is int.init;
    }

    @nogc
    bool isGrounded() pure const nothrow {
        return
            (_mother is null) && (event_package.event_body.mother !is null) ||
            (_father is null) && (event_package.event_body.father !is null);
    }

    @nogc
    immutable(Buffer) fingerprint() const pure nothrow {
        return event_package.fingerprint;
    }

    @nogc
    package Range!false opSlice() pure nothrow {
        return Range!false (this);
    }

    @nogc
    Range!true opSlice() const pure nothrow {
        return Range!true (this);
    }

    @nogc
    struct Range(bool CONST=true) {
        private Event current;
        @trusted
        this(const Event event) pure nothrow {
            current=cast(Event)event;
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

            alias back=front;

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
