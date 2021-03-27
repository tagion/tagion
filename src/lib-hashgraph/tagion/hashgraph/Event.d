module tagion.hashgraph.Event;

import std.stdio;
import core.stdc.stdio;
import std.datetime;   // Date, DateTime
import std.exception : assumeWontThrow;
import std.conv;
//import std.bitmanip;

import std.format;
import std.typecons;
import std.traits : Unqual, ReturnType;
import std.range : enumerate;
import std.array : array;

//import std.algorithm.searching : all;
import std.algorithm.iteration : map, each, filter, cache;
import std.algorithm.searching : count, any, all;
import std.range.primitives : walkLength, isInputRange, isForwardRange, isBidirectionalRange;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord ;

import tagion.utils.Miscellaneous;
import tagion.utils.StdTime;

//import tagion.gossip.InterfaceNet;

import tagion.basic.Basic : this_dot, basename, Pubkey, Buffer, bitarray_clear, bitarray_change, EnumText, buf_idup;
//import tagion.hashgraph.HashGraphBasic : isMajority, check;
import tagion.Keywords : Keywords;

import tagion.basic.Logger;
import tagion.hashgraph.HashGraphBasic : isMajority, EventBody, EventPackage, EvaPayload, Tides, EventMonitorCallbacks, EventScriptCallbacks;
import tagion.hashgraph.HashGraph : HashGraph;
import tagion.hashgraph.BitMask : BitMask;

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
    enum uint total_limit = 3;
    enum int coin_round_limit = 10;
    private Round _previous;
    private Round _next;
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

    version(none)
    private void disconnect()
    in {
        // if (_previous !is null) {
        //     log.warning("Only the last round can be disconnected (round %d)", number);
        // }
        //   assert((_previous is null) || (_previous is _seed_round), "Only the last round can be disconnected");
        assert(_event_counts is 0, "All witness must be removed before the round can be disconnected");
    }
    do {
        if (_previous !is null) {
            log.warning("Not the last to be disconnected (round %d) events_count=%d", number, _event_counts);
            if (_previous._event_counts !is 0) {
                log.warning("Round is not disconnected because the previuos rounds still contains events (round %d) events_count=%d", number, _previous._event_counts);
                return;
            }
            _previous.disconnect;
            // && (_previous._event_counts is 0)) {
            // _previous.disconnect;
        }
        else {
            Round before;

            for(before=_rounds; (before !is null) && (before._previous !is this); before=before._previous) {
                // Empty
            }

            before._previous=null;
//            _decided_count--;
        }
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
            assert(_events[event.node_id] is event, "This event does not exist in round at the current node so it can not be remove from this round");
            assert(!empty, "No events exists in this round");
        }
    do {
        if ( _events[event.node_id] ) {
            _events[event.node_id]=null;
        }
    }

    @nogc
    inout(Event) event(const size_t node_id) pure inout {
        return _events[node_id];
    }

    private void consensus_order(HashGraph hashgraph) {
        assert(0, "Not implemented yet");
    }

    version(none)
    private void consensus_order(HashGraph hashgraph)
        in {
        }
    do {
        // import std.stdio;
        // writeln("consensus order");
        import std.algorithm : sort, SwapStrategy;
        import std.functional;
        import tagion.hibon.HiBONJSON;
        scope Event[] famous_events=new Event[_events.length];
        BitMask unique_famous_mask;
        //bitarray_change(unique_famous_mask, node_size);
        @trusted
            sdt_t find_middel_time() {
            try{
                log("finding middel time");
                size_t famous_node_id;
                foreach(e; _events) {
                    if(e is null){
                        log.trace("(event is null)");
                        //stdout.flush();
                        // writeln(Document(e.toHiBON.serialize).toJSON);
                    }
                    if(e._witness is null){
                        //log("witness is null");
                        //stdout.flush();
                        //log.error("(witness is null) %s", Document(e.toHiBON.serialize).toJSON);
                    }
                    else{
                        //log("ok");
                        if (e._witness.famous(hashgraph.node_size)) {
                            famous_events[famous_node_id]=e;
                            unique_famous_mask[famous_node_id]=true;
                            famous_node_id++;
                        }
                    }
                }
                famous_events.length=famous_node_id;
                // Sort the time stamps
                famous_events.sort!((a,b) => (Event.timeCmp(a,b) <0));
                log("famous sorted");
                // Find middel time
                immutable middel_time_index=(famous_events.length >> 2) + (famous_events.length & 1);
                log.trace("middle time index: %d, len: %d", middel_time_index, famous_events.length);
                //stdout.flush();
                scope(exit){
                    log("calc successfully");
                }
                return famous_events[middel_time_index].eventbody.time;
            }
            catch(Exception e){
                import tagion.basic.TagionExceptions : fatal;
                fatal(e);
                // writeln("exc: ", e.msg);
                // throw e;
            }
        }

        immutable middel_time=find_middel_time;
        immutable number_of_famous=cast(uint)famous_events.length;
        //
        // Clear round received counters
        //
        foreach(event; famous_events) {
            Event event_to_be_grounded;
            bool trigger;
            void clear_round_counters(Event e) nothrow {
                if ( e && !e.isGrounded ) {
                    if ( !trigger && e.round_received ) {
                        trigger=true;
                        event_to_be_grounded=e;
                    }
                    else if ( !e.round_received ) {
                        trigger=false;
                        event_to_be_grounded=null;
                    }
                    e.clear_round_received_count;
                    clear_round_counters(e._mother);
                }
            }
            clear_round_counters(event._mother);
        }
        //
        // Select the round received events
        //
        Event[] round_received_events;
        foreach(event; famous_events) {
            Event.visit_marker++;
            void famous_seeing_count(Event e) {
                if ( e && !e.visit && !e.isGrounded ) {
                    if ( e.check_if_round_was_received(number_of_famous, this) ) {
                        round_received_events~=e;
                    }
                    famous_seeing_count(e._mother);
                    famous_seeing_count(e._father);
                }
            }
            famous_seeing_count(event);
        }
        //
        // Consensus sort
        //
        sort!((a,b) => ( a<b ), SwapStrategy.stable)(round_received_events);


        if ( Event.scriptcallbacks ) {
            log("EPOCH received %d time=%d", round_received_events.length, middel_time);
            Event.scriptcallbacks.epoch(round_received_events, middel_time);
        }

        if ( Event.callbacks ) {
            log.trace("Total (Events=%d Witness=%d Rounds=%d)", Event.count, Event.Witness.count, hashgraph.rounds.cached_count);
            Event.callbacks.epoch(round_received_events);
        }
    }


    @nogc
    package inout(Round) previous() inout pure nothrow {
        return _previous;
    }


    invariant {
        void check_round_order(const Round r, const Round p) pure {
            if ( ( r !is null) && ( p !is null ) ) {
                assert( (r.number-p.number) == 1,
                    format("Consecutive round-numbers has to increase by one (rounds %d and %d)", r.number, p.number));
                // if ( r._decided ) {
                //     assert( p._decided, "If a higher round is decided all rounds below must be decided");
                // }
                check_round_order(r._previous, p._previous);
            }
        }
        check_round_order(this, _previous);
    }


    struct Rounder {
        Round _last_round;
        Round last_decided_round;
        HashGraph hashgraph;

        @disable this();

        this(HashGraph hashgraph) pure nothrow {
            this.hashgraph=hashgraph;
            last_decided_round = _last_round = new Round(null, hashgraph.node_size);
            debug assumeWontThrow(
                (() @trusted {
                    printf("%p New Rounder (%d)\n", last_round, last_round.number);})());

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
            //log.error("isEva %s (last_round is null) = %s", e.isEva, (last_round is null));
            if (!e.isFatherLess) {
                // log.error("e.isFatherLess");
                scope (exit) {
                    e._round.add(e);
                }
                if (e._round && e._round._next) {
                    // assumeWontThrow(
                    //     writefln("Next Round (%d)", e._round._next.number));
                    //log.error("EVA Defined");
                    e._round = e._round._next;
                    //assert(e._round !is null);
                }
                else {
                    //log.error("EVA create round");
                    // debug assumeWontThrow(
                    //     (() @trusted {
                    //         printf("%p New Round (%d) before\n", _last_round, last_round.number);})());
                    e._round = new Round(last_round, hashgraph.node_size);
                    _last_round = e._round;
                    // debug assumeWontThrow(
                    //     (() @trusted {
                    //         printf("%p New Round (%d) after\n", _last_round, last_round.number);})());

                    // void dump(const Round round) pure nothrow {
                    //     if (round) {
                    //         debug assumeWontThrow(
                    //             writef("(%d) ", round.number));
                    //         dump(round._previous);
                    //     }
                    //     debug assumeWontThrow(
                    //         writeln());
                    // }
                    // debug assumeWontThrow(
                    //     (() @trusted {
                    //         writefln("rounds.length = %d", length);
                    //         writefln("rounds = (%s)", this[].map!((a) => a.number));})());
//                    dump(last_round);
                    if (Event.callbacks) {
                        Event.callbacks.round_seen(e);
                    }
                    //assert(e._round !is null);
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

        // void dump() const nothrow {
        //     log("ROUND dump");
        //     void _dump(const Round r) nothrow {
        //         if (r) {
        //             log("\tRound %d %s", r.number, decided(r));
        //             _dump(r._previous);
        //         }
        //     }
        //     return _dump(last_decided_round);
        // }


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

        private void decide() {
            auto round_to_be_decided = last_decided_round._next;
            scope(success) {
                last_decided_round = round_to_be_decided;
                if ( Event.callbacks ) {
                    Event.callbacks.round_decided(hashgraph._rounds);
                }
            }
            round_to_be_decided.consensus_order(hashgraph);
        }

        @nogc
        bool check_decided_round_limit() pure const nothrow {
            return cached_decided_count > total_limit;
        }

        void check_decided_round(const size_t node_size)
            in {
                assert(last_decided_round, "Not decided round found");
            }
        do {
            if (last_decided_round._next && last_decided_round._next._next) {
                uint famous_votes;
                foreach(ref e; last_decided_round._next._events) {
                    if (e && e._witness) {
                        if (e._witness._famous) {
                            famous_votes++;
                        }
                        else {
                            BitMask strong_seeing_mask;
                            //bitarray_clear(strong_seeing_mask, node_size);
                            /// See through the next round
                            auto next_round = e._round._next;
                            const(BitMask) calc_seeing_mask() @safe pure nothrow {
                                BitMask result;
                                //result.length=node_size;
                                foreach(seeing_node_id; e._witness._seen_in_next_round_mask[]) {
                                    if (next_round._events[seeing_node_id]) {
                                        result |= next_round._events[seeing_node_id]._witness._seen_in_next_round_mask;
                                    }
                                }
                                return result;
                            }

                            const seeing_mask=calc_seeing_mask;

                            bool famous_search(ref const(BitMask) seeing_mask,
                                ref scope const(Round) current_round) @safe {
                                if (current_round) {
                                    const seeing_through=seeing_mask.isMajority(node_size);
                                    BitMask next_seeing_mask;
                                    //next_seeing_mask.length=node_size;
                                    //bitarray_clear(next_seeing_mask, node_size);
                                    foreach(next_node_id, e; current_round._events) {
                                        if (seeing_mask[next_node_id] && e) {
                                            next_seeing_mask |= next_round._events[next_node_id]._witness._seen_in_next_round_mask;
                                            if (seeing_through && next_seeing_mask.isMajority(node_size)) {
                                                return true;
                                            }
                                        }
                                    }
                                    return famous_search(next_seeing_mask, current_round._next);
                                }
                                return false;
                            }
                            e._witness._famous = seeing_mask.isMajority(node_size) && famous_search(seeing_mask, next_round._next);
                            if (e._witness.famous(node_size)) {
                                famous_votes++;
                                if (Event.callbacks) {
                                    Event.callbacks.famous(e);
                                }
                            }
                        }
                    }
                }
                if (last_decided_round._next.event_count == famous_votes) {
                    decide;
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
    static void _print(string pref, const Event e) @safe  {
        import std.stdio;
         version(none) {
        writef("%s\t(%d:%d:%d)@%s %s->", pref, e.node_id, e.id, e.altitude, e.fingerprint.cutHex, e.isGrounded?"G":"");
        if (e._mother) {
            string daughter() {
                if (e._mother._daughter) {
                    return format("d(%d:%d:%d)", e._mother._daughter.node_id, e._mother._daughter.id, e._mother._daughter.altitude);
                }
                return "";
            }
            writef(" m(%d:%d:%d)%s@%s", e._mother.node_id, e._mother.id, e._mother.altitude, daughter, e.event_package.event_body.mother.cutHex);
        }
        else {
            writef(" m(#)@%s", e.event_package.event_body.mother.cutHex);
        }
        if (e._father) {
            string son() {
                if (e._father) {
                    return format("s(%d:%d:%d)", e._father._son.node_id, e._father._son.id, e._father.altitude);
                }
                return "";
            }
            writef(" f(%d:%d)%s@%s", e._father.node_id, e._father.id, son, e.event_package.event_body.father.cutHex);
        }
        else {
            writef(" f(#)@%s",e.event_package.event_body.father.cutHex);
        }
        writeln();
        }
    }


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

        //version(none)
        if ( isEva ) {
            // If the event is a Eva event the round is undefined
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
//    package static Event f
    // static Event createEva(HashGraphI hashgraph, const sdt_t time, const Buffer nonce) {

    // }

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
//            Event _previous_witness_event;
            BitMask _famous_decided_mask;
            BitMask _strong_seeing_mask;
            // This vector shows what we can see in the previous witness round
///            // Round seeing masks from next round
            BitMask _seen_in_next_round_mask;
            uint     _round_seen_count;
            uint     _famous_votes;
            bool     _famous_decided;
            bool _famous;
        }

        @trusted
        this(Event owner_event, ref const(BitMask) seeing_witness_in_previous_round_mask) nothrow
        in {
            //assert(seeing_witness_in_previous_round_mask.length > 0);
            assert(owner_event);
        }
        do {
            _seeing_witness_in_previous_round_mask=cast(immutable)seeing_witness_in_previous_round_mask.dup;
            //_famous_decided_mask.length=node_size;
            _count++;
        }

        ~this() {
            _count--;
        }

        // @nogc
        // uint node_size() pure const nothrow {
        //     return cast(uint)_strong_seeing_mask.length;
        // }

        // @nogc
        // inout(Event) previous_witness_event() inout pure nothrow {
        //     return _previous_witness_event;
        // }

        @nogc
        const(BitMask) strong_seeing_mask() pure const nothrow {
            return _strong_seeing_mask;
        }

        @trusted
        private void seen_from_previous_round(Event owner_event) nothrow
            in {
                assert(owner_event._witness is this, "The owner_event does not own this witness");
                assert(owner_event._round, "Event must have a round");
                //assert(owner_event._round._previous, "The round of this witness must have a previous round");
            }
        do {
            if (owner_event._round._previous) {
            scope(success) {
                // The witness mask for a witness is set to node_id
                //owner_event._witness_mask.bitarray_clear(owner_event._witness_mask.length);
                owner_event._witness_mask[owner_event.node_id] = true;
            }
            foreach(privous_witness_node_id, e; owner_event._round._previous._events) {
                if (e) {
                    if (owner_event._witness_mask[privous_witness_node_id]) {
                        e._witness._seen_in_next_round_mask[privous_witness_node_id] = true;
                    }
                }
            }
            }
        }

        @nogc
        ref const(BitMask) round_seen_mask() pure const nothrow {
            return _seeing_witness_in_previous_round_mask;
        }


        @trusted
        bool famous_decided() pure const nothrow {
            return _famous_decided;
        }

        @nogc
        uint famous_votes() pure const nothrow {
            return _famous_votes;
        }

        @nogc
        bool famous(const size_t node_size) pure const nothrow {
            return isMajority(_famous_votes, node_size);
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

    // Recursive markes
    private uint _visit;
    package static uint visit_marker;
    @nogc
    private bool visit() nothrow {
        scope(exit) {
            _visit = visit_marker;
        }
        return (_visit == visit_marker);
    }
    // The altitude increases by one from mother to daughter
    immutable(EventPackage*) event_package;

    ref const(EventBody) event_body() const nothrow {
        return event_package.event_body;
    }

    protected {
        //    Buffer _fingerprint;
        // This is the internal pointer to the
        Event _mother;
        Event _father;
        Event _daughter;
        Event _son;

        int _received_order;
        // Round  _round;
        // Round  _round_received;
        uint _round_received_count;

        // The withness mask contains the mask of the nodes
        // Which can be seen by the next rounds witness

        Witness _witness;
//        uint _witness_votes;
        BitMask _witness_mask;
        uint     _mark;
        static uint _marker;
    }

    private {
        Round  _round;
        Round  _round_received;
    }

    version(none)
    @nogc
    size_t witness_votes() const pure nothrow {
        return _witness_mask.count;
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

    @nogc
    package bool is_marked() const nothrow {
        return _marker is _mark;
    }

    @nogc
    package void mark() nothrow {
        _mark=_marker;
    }

    @nogc
    package static void set_marker() nothrow {
        _marker++;
    }

    // @nogc @property
    // private uint node_size() pure const nothrow {
    //     return cast(uint)witness_mask.length;
    // }

    immutable uint id;
    protected {
//        static uint id_count;


        bool _strongly_seeing_checked;
        bool _loaded;
        // This indicates that the hashgraph aften this event
        bool _forked;
//        bool _grounded;
    }

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

    version(none)
    private bool check_if_round_was_received(const uint number_of_famous, Round received) {
        if ( round_received !is int.init ) {
            _round_received_count++;
            if ( _round_received_count == number_of_famous ) {
                _round_received=received;
                if ( callbacks ) {
                    callbacks.round_received(this);
                }
                return true;
            }
        }
        return false;
    }

    @nogc
    private void clear_round_received_count() pure nothrow {
        if ( !_round_received ) {
            _round_received_count=0;
        }
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

    version(none)
    @nogc
    Round round() nothrow
        in {
            if ( !isGrounded ) {
                assert(_mother, "Graph has not been resolved");
            }
        }
    out(result) {
        assert(result, "No round was found for this event");
    }
    do {
        if ( !_round ) {
            _round=_mother._round;
        }
        return _round;
    }

    version(none)
    private size_t witness_votes(immutable uint node_size) {
        witness_mask(node_size);
        return witness_votes;
    }

    version(none)
    @nogc
    uint witness_votes() pure const nothrow
        in {
            assert(is_witness_mask_checked);
        }
    do {
        return _witness_votes;
    }

    version(none)
    @nogc
    bool is_witness_mask_checked() pure const nothrow {
        return _witness_mask.length != 0;
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

    @nogc
    package void strongly_seeing_checked() nothrow
    in {
        assert(!_strongly_seeing_checked);
    }
    do {
        _strongly_seeing_checked=true;
    }

    @nogc
    bool is_strongly_seeing_checked() const pure nothrow {
        return _strongly_seeing_checked;
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

    private void forked(bool s)
        in {
            if ( s ) {
                assert(!_forked, "An event can not unforked");
            }
        }
    do {
        _forked = s;
        if ( callbacks && _forked ) {
            callbacks.forked(this);
        }
    }


    @nogc
    bool forked() const pure nothrow {
        return _forked;
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
// Disconnect the Event from the graph
    version(none)
    @nogc
    static int received_order_max(const(Event) mother, const(Event) father) pure nothrow {
        if (mother && mother.isFatherLess && mother.nodeOwner) {
            // If the node is father less and the mother is not produced byt 'this' node
            // then the order is undefined;
            return int.init;
        }
        const a=(mother)?mother._received_order:int.init;
        const b=(father)?father._received_order:int.init;
        const result=((a-b > 0)?a:b)+1;
        return (result is int.init)?1:result;
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

    void order() {
        if (isFatherLess) {
            if (_mother) {
                if (_mother._received_order is int.init) {
                    _mother.order;
                }
                _received_order = expected_order;
            }
        }
        else if (_received_order is int.init) {
            _received_order = expected_order;
            if (_received_order !is int.init) {
                order;
            }
        }
        else {
            const expected = expected_order;
            if ((expected - _received_order) > 0) {
                _received_order = expected;
                if (_son) {
                    _son.order;
                }
                if (_daughter) {
                    _daughter.order;
                }

            }
            else if ((expected - _received_order) < 0) {
                if (_father) {
                    _father.order;
                }
                if (_mother) {
                    _mother.order;
                }
                _received_order = expected_order;
                if (_son) {
                    _son.order;
                }
                if (_daughter) {
                    _daughter.order;
                }

            }
        }
    }

    // +++
    @trusted
    private const(BitMask) calc_witness_mask(HashGraph hashgraph) //nothrow
        in {
            assert(!_mother._witness_mask[].empty);
        }
    do {
        uint iterative_witness_search_count;
        scope(exit) {
            hashgraph.witness_search_statistic(iterative_witness_search_count);
        }
        const(BitMask) local_calc_witness_mask(const Event e, const BitMask voting_mask, scope const BitMask marker_mask) {
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


    @trusted
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
            //witness_front = hashgraph.witness_front;
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
                order;
                auto witness_seen_mask = calc_witness_mask(hashgraph);
                if ( witness_seen_mask.isMajority(hashgraph.node_size) ) {
                    hashgraph._rounds.next_round(this);
                    _witness = new Witness(this, witness_seen_mask);
                    _witness.seen_from_previous_round(this);
                    if ( callbacks) {
                        callbacks.witness(this);
                    }
                    hashgraph._rounds.check_decided_round(hashgraph.node_size);
                    _witness_mask.clear;
                    _witness_mask[node_id]=true;

                }

            }
            else if (!isEva) {
                check(false, ConsensusFailCode.EVENT_MOTHER_LESS);
            }
        }
    }

    // @nogc
    // int calc_order() const pure nothrow {
    //     const m=(_mother)?_mother._received_order:int.init;
    //     const f=(_father)?_father._received_order:int.init;
    //     return (m-f > 0)?m:f;
    // }

    enum first_eva_order = -3;
    @nogc
    package void set_eva_order() pure nothrow
        in {
            assert(_received_order is int.init, "Eva event has already been set");
            assert(isEva, "Must be an Eva event");
            assert(nodeOwner, "Eva order can only be set by the node producing the Eva event");
        }
    do {
        _received_order = first_eva_order;
    }

    @nogc
    int received_order() const pure nothrow {
    //     in {
    //         assert(_received_order !is int.init, "The received order of this event has not been defined");
    //     }
    // do {
        return _received_order;
    }

    version(none)
    int received_order() pure nothrow {
        if (_received_order is int.init) {
            bool end_search;
            int local_received_order(Event event) {
                if (event) {
                    if ((event._received_order is int.init) && !end_search) {
                        int result;
                        scope(exit) {
                            if (result !is int.init) {
                                // Increase by one
                                result++;
                                event._received_order = (result is int.init)?int.init+1:result;
                                // debug writefln("### Result %d", event._received_order);
                            }
                        }
                        const mother_order = local_received_order(event._mother);
                        if (mother_order is int.init) {
                            //debug writefln("### mother undefined");
                            if (event._father) {
                                const father_order = local_received_order(event._father);
                                if (father_order !is int.init) {
                                    int order=father_order;
                                    for(Event next=event._mother; next !is null; next=next._mother) {
                                        order--;
                                        order = (order is int.init)?int.init-1:order;
                                        next._received_order = order;
                                    }
                                    result = father_order;
                                }
                                else {
                                    end_search=true;
                                }
                            }
                        }
                        else {
                            // debug writefln("### DEFINED mother_order=%d", mother_order);
                            if (_father) {
                                const father_order = local_received_order(event._father);
                                result = (mother_order > father_order)?mother_order:father_order;
                            }
                            else {
                                result = mother_order;
                            }
                        }
                    }
                    return event._received_order;
                }
                return int.init;
            }
            //debug writefln("### \tEnd %d:%d", id, node_id);
            _received_order = local_received_order(this);

        }
        return _received_order;
    }
// +++
    @nogc
    bool connected() const pure nothrow {
//        return (_mother !is null) || isEva;
        return (_mother !is null);
    }


    const(Event) mother() const pure {
        Event.check(!isGrounded, ConsensusFailCode.EVENT_MOTHER_GROUNDED);
        return _mother;
    }

    @nogc
    const(Event) father() const pure nothrow
    in {
        if ( event_package.event_body.father ) {
            assert(_father);
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

    version(none)
    @nogc
    bool motherExists() const pure nothrow {
        return event_package.event_body.mother !is null;
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
        return isEva || (event_package.event_body.father is null) && _mother.isFatherLess;
    }

    @nogc
    bool hasOrder() pure const nothrow {
        return _received_order !is int.init;
    }

    @nogc
    bool isGrounded() pure const nothrow {
        return (_mother is null) && (event_package.event_body.mother !is null);
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
                Event front() {
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

version(none)
unittest { // Serialize and unserialize EventBody
    import std.digest.sha;

    HiBON hibon;
    hibon=new HiBON;
    hibon["payload"]="Some payload";
    const payload=Document(hibon);
//    auto mother=SHA256(cast(uint[])"self").digits;
    immutable mother=sha256Of("self");
    immutable father=sha256Of("other");
    auto seed_body=EventBody(payload, mother, father, 0, 0);

    auto raw=seed_body.serialize;

    auto replicate_body=EventBody(raw);

    // Raw and repicate should be the same
    assert(seed_body == replicate_body);
//    auto seed_event=new Event(seed_body);
}
