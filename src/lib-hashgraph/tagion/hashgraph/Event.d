module tagion.hashgraph.Event;

import std.datetime;   // Date, DateTime
import  std.exception : assumeWontThrow;
import std.conv;
import std.bitmanip;

import std.format;
import std.typecons;
import std.traits : Unqual;
import std.range : enumerate;
//import std.algorithm.searching : all;
import std.algorithm.iteration : map, each, filter;
import std.algorithm.searching : count;
import std.range.primitives : walkLength;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord ;

import tagion.utils.Miscellaneous;

import tagion.gossip.InterfaceNet;

import tagion.basic.Basic : this_dot, basename, Pubkey, Buffer, bitarray_clear, bitarray_change, countVotes, EnumText, buf_idup;
//import tagion.hashgraph.HashGraphBasic : isMajority, check;
import tagion.Keywords : Keywords;

import tagion.basic.Logger;
import tagion.hashgraph.HashGraphBasic : isMajority, HashGraphI, EventBody, EventPackage, Tides, EventMonitorCallbacks;

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
interface EventScriptCallbacks {
    void epoch(const(Event[]) received_event, immutable long epoch_time);
    void send(ref Document[] payloads, immutable long epoch_time); // Should be execute when and epoch is finished

    void send(immutable(EventBody) ebody);
    bool stop(); // Stops the task
}


@safe
class Round {
    package bool __grounded;
    enum uint total_limit = 3;
    enum int coin_round_limit = 10;
    private Round _previous;
    private Round _next;
    // Counts the number of nodes in this round
    immutable int number;
//    private bool _decided;
//    private static uint _decided_count;

    private BitArray _looked_at_mask;
    private uint _looked_at_count;
    static int increase_number(const(Round) r) nothrow pure {
        return r.number+1;
    }

    private Event[] _events;
    // Counts the witness in the round
    private uint _event_counts;
//    private static Round _rounds;
    // @nogc static uint count() nothrow {
    //     uint result;
    //     for(Round r=_rounds; r !is null; r=r._previous) {
    //         result++;
    //     }
    //     return result;
    // }
    // Last undecided round
//    private static Round _undecided;
    //
    private BitArray _ground_mask;

    @nogc bool lessOrEqual(const Round rhs) pure const nothrow {
        return (number - rhs.number) <= 0;
    }

    @nogc const(uint) node_size() pure const nothrow {
        return cast(uint)_events.length;
    }

    @nogc uint famousVote() pure const nothrow {
        return cast(uint)(opSlice.map!((e) => (e !is null) && (e.witness.famous)).count(true));
    }

    private @nogc bool famous_can_be_decided() pure const nothrow {
        return famousVote == _event_counts;
    }

    private this(Round previous, const size_t node_size, immutable int round_number) pure nothrow {
        // if ( r is null ) {
        //     // First round created
        //     _decided=true;
        // }
        _previous=previous;
        if (previous) {
            previous._next = this;
        }
        number=round_number;
        _events=new Event[node_size];
        bitarray_clear(_looked_at_mask, node_size);
        bitarray_clear(_ground_mask, node_size);
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

    version(none)
    private Round next_consecutive() {
        return _rounds=new Round(_rounds, node_size, _rounds.number+1);
//        return _rounds;
    }

    // Used to make than an witness in the next round at the node_id has looked at this round
    @trusted @nogc
    package void looked_at(const uint node_id) nothrow {
        if ( !_looked_at_mask[node_id] ) {
            _looked_at_mask[node_id]=true;
            _looked_at_count++;
        }
    }

    // Checked if all active nodes/events in this round has beend looked at
    @nogc
    bool seeing_completed() const pure nothrow {
        return _looked_at_count == node_size;
    }

    @nogc
    ref const(BitArray) looked_at_mask() pure const nothrow {
        return _looked_at_mask;
    }

    @nogc
    uint looked_at_count() pure const nothrow {
        return _looked_at_count;
    }

    version(none)
    private static Round _seed_round;
    version(none)
    package static Round seed_round(const uint node_size) {
        if ( _rounds is null ) {
            _rounds = _seed_round = new Round(null, node_size, -1);
            //_seed_round._decided=true;
        }
        // Use the latest round as seed round
        return _rounds;
    }

    version(none)
    static Round opCall(const int round_number)
    in {
        assert(_rounds, "Seed round has to exists before the operation is used");
    }
    do {
        Round find_round(Round r) pure nothrow {
            if ( r ) {
                if ( r.number == round_number ) {
                    return r;
                }
                return find_round(r._previous);
            }
            assert(0, "No round found");
        }
        immutable round_space=round_number - _rounds.number;
        if ( round_space == 1) {
            return _rounds.next_consecutive;
        }
        else if ( round_space <= 0 ) {
            return find_round(_rounds);
        }
        assert(0, "Round number must increase by one");
    }

    package int opApply(scope int delegate(const uint node_id, ref Event event) @safe dg) {
        int result;
        foreach(node_id, ref e; _events) {
            if ( e ) {
                result=dg(cast(uint)node_id, e);
                if ( result ) {
                    break;
                }
            }
        }
        return result;
    }

    int opApply(scope int delegate(const uint node_id, const(Event) event) @safe dg) const {
        int result;
        foreach(node_id, e; _events) {
            if ( e ) {
                result=dg(cast(uint)node_id, e);
                if ( result ) {
                    break;
                }
            }
        }
        return result;
    }

    @nogc
    package Range!false range() pure nothrow {
        return Range!false(this);
    }

    @nogc
    Range!true opSlice() const pure nothrow {
        return Range!true(this);
    }

    @nogc
    struct Range(bool CONST=false) {
        static if (CONST) {
            private const(Event)[] _events;
            this(const(Round) r) nothrow pure {
                _events=r._events;
            }
        }
        else {
            private Event[] _events;
            this(Round r) nothrow pure {
                _events=r._events;
            }
        }
        @property pure {
            bool empty() const {
                return _events.length is 0;
            }

            static if (CONST) {
                const(Event) front() const {
                    return _events[0];
                }
            }
            else {
                Event front() {
                    return _events[0];
                }
            }

            void popFront() {
                _events=_events[1..$];
            }
        }
    }

    //  @nogc
    package void add(Event event) nothrow
    in {
        assert(_events[event.node_id] is null, "Event at node_id "~event.node_id.to!string~" should only be added once");
    }
    do {
//        if ( _events[event.node_id] is null ) {
        log.error("Add node_id %d", event.node_id);
        _event_counts++;
        _events[event.node_id]=event;
//        }
        // if (this is _seed_round) {
        //     log.error("Node %d add to seed_round (event_count=%d)", event.node_id, _event_counts);
        // }
    }

    @nogc
    private void remove(const(Event) event) nothrow
        in {
            assert(_events[event.node_id] is event, "This event does not exist in round at the current node so it can not be remove from this round");
            assert(_event_counts > 0, "No events exists in this round");
        }
    do {
        if ( _events[event.node_id] ) {
            _event_counts--;
            _events[event.node_id]=null;
        }
        // if (this is _seed_round) {
        //     log.error("Node %d removed to seed_round (event_count=%d)", event.node_id, _event_counts);
        // }
    }

    @nogc
    bool empty() pure const nothrow {
        return _event_counts == 0;
    }

    // Return true if all witness in this round has been created
    @nogc
    bool completed() pure const nothrow {
        return _event_counts == node_size;
    }

    @nogc
    inout(Event) event(const size_t node_id) pure inout {
        return _events[node_id];
    }

    // // Whole round decided
    // @nogc
    // bool decided() pure const nothrow {

    //     return _decided;
    // }


    @trusted @nogc
    private bool ground(const size_t node_id, ref const(BitArray) rhs) nothrow {
        _ground_mask[node_id]=true;
        return rhs == _ground_mask;
    }

    @nogc
    ref const(BitArray) ground_mask() pure const nothrow {
        return _ground_mask;
    }

    // @trusted
    // bool check_ground_mask(ref const(BitArray) rhs) {
    //     return rhs == _ground_mask;
    // }
    version(none)
    private void seeing_previous_round(Event e)
    in {
        assert(_events[e.node_id] is e, format("Event at node_id=%d has not been added to the round", e.node_id));
        assert(e._witness !is null, "Event must be a witness");
    }
    do {
        scope(success) {
            // The witness mask for a witness is set to node_id
            e._witness_mask = bitarray_clear(e._witness_mask.length);
            e._witness_mask[node_id] = true;
        }

    }

    private void consensus_order(HashGraphI hashgraph)
        in {
        }
    do {
        // import std.stdio;
        // writeln("consensus order");
        import std.algorithm : sort, SwapStrategy;
        import std.functional;
        import tagion.hibon.HiBONJSON;
        scope Event[] famous_events=new Event[_events.length];
        BitArray unique_famous_mask;
        bitarray_change(unique_famous_mask, node_size);
        @trusted
            ulong find_middel_time() {
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
                        log.error("(witness is null) %s", Document(e.toHiBON.serialize).toJSON);
                    }
                    else{
                        //log("ok");
                        if (e._witness.famous) {
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
                if ( e && !e.grounded ) {
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

//            version(none)
            if ( event_to_be_grounded ) {
                event_to_be_grounded._grounded=true;
                if ( event_to_be_grounded._round._previous ) {
                    if ( event_to_be_grounded._round._previous.ground(event_to_be_grounded.node_id, unique_famous_mask) ) {
                        // scrap round!!!!
                    }
                }
            }
        }
        //
        // Select the round received events
        //
        Event[] round_received_events;
        foreach(event; famous_events) {
            Event.visit_marker++;
            void famous_seeing_count(Event e) {
                if ( e && !e.visit && !e.grounded ) {
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
            import std.stdio;
            log("EPOCH received %d time=%d", round_received_events.length, middel_time);
            Event.scriptcallbacks.epoch(round_received_events, middel_time);
        }

        if ( Event.callbacks ) {
            log.trace("Total (Events=%d Witness=%d Rounds=%d)", Event.count, Event.Witness.count, hashgraph.rounds.cached_count);
            Event.callbacks.epoch(round_received_events);
        }
    }

    version(none)
    private void decide()
    in {
        assert(!decided, "Round should only be decided once");
        assert(this is Round.undecided_round, "Round can only be decided if it is the lowest undecided round in the round stack");
    }
    // out{
    //     assert(_undecided._previous._decided, "Previous round should be decided");
    // }
    do {
        // @nogc
        //     Round one_over(Round r=_rounds) nothrow pure {
        //     if ( r._previous is this ) {
        //         return r;
        //     }
        //     return one_over(r._previous);
        // }
        // _undecided = one_over;
        // _decided = true;
        // _decided_count++;
        if ( Event.callbacks ) {
            Event.callbacks.round_decided(this);
        }
        consensus_order;
        last_decided_round = last_decided_round._next;
        //return check_decided_round_limit;
        // if (check_decided_round_limit) {
        //     scrap(h);
        // }
    }

    // Returns true of the round can be decided
    version(none)
    bool can_be_decided() const
    in {
        assert( _previous, "This is not a valid round to ask for a decision, because not round below exists");
    }
    do {
        if ( _decided ) {
            return true;
        }
        if ( seeing_completed && completed ) {
            if ( _previous ) {
                foreach(node_id, e; this) {
                    if ( !e._witness.famous_decided ) {
                        return false;
                    }
                }
                return true;
            }
        }
        return false;
    }

    // Find collecting round from which the famous votes is collected from the previous round
    version(none)
    @nogc
    package static Round undecided_round() nothrow {
        if ( !_undecided ) {
            Round search(Round r=_rounds) @safe {
                if ( r && r._previous && r._previous._decided ) {
                    return r;

                }
                return search(r._previous);
            }
            _undecided = search();
        }
        return _undecided;
    }

    @nogc
    package inout(Round) previous() inout pure nothrow {
        return _previous;
    }

    /// Find the lowest decided round
    version(none)
    @nogc
    static Round lowest() pure nothrow {
        Round local_lowest(Round r=_rounds) {
            if ( r ) {
//                if ( r._decided && r._previous && (r._previous._previous is null ) ) { //&& (!r._previous._previous.__grounded) ) {
                if ( r._decided && r._previous && ((!r._previous.__grounded) || (r._previous._previous is null )) ) {
                    return r;
                }
                return local_lowest(r._previous);
            }
            return null;
        }
        return local_lowest;
    }

    // Scrap the lowest Round
//     static void _scrap(H)(H hashgraph) {
//         // Scrap the rounds and events below this
//         void local_scrap(Round r) @trusted {
//             foreach(node_id, ref e; r[].enumarate) {
//                 void scrap_event(Event e) {
//                     if ( e ) {
//                         scrap_event(e._mother);
//                         if ( Event.callbacks ) {
//                             Event.callbacks.remove(e);
//                         }
//                         hashgraph.eliminate(e.fingerprint);
//                         e.disconnect;
//                         e.destroy;
//                     }
//                 }
//                 scrap_event(e._mother);
//                 if ( e ) {
//                     assert(e._mother is null);
//                 }
//             }
//         }
//         Round _lowest=lowest;
// //        version(none)
//         if ( _lowest ) {
//             local_scrap(_lowest);
//         }
//     }

    // Scrap the lowest Round
    version(none)
    package static void scrap(HashGraph h) {
        // Scrap the rounds and events below this
        void local_scrap(Round r) @trusted {
            if (r[].all!(a => (a) && (a._round_received !is null))) {
                import core.memory : GC;
//                log.fatal("round.decided=%s round=%d usedSize=%d", r._decided, r.number, GC.stats.usedSize);
//                r.range.each!(a => a._grounded = true);
                r.range.each!((a) => {if (a) {a.disconnect(h);}});

            }
//             version(none) {
//                 scope round_numbers = new int[r.node_size];
//                 scope round_received_numbers = new int[r.node_size];
//                 bool sealed_round=true;
//                 // scope(exit) {
//                 //     log.fatal("round.decided=%s", r._decided);
//                 //     log.fatal("   round:%s", round_numbers);
//                 //     log.fatal("received:%s", round_received_numbers);
//                 //     if (sealed_round) {
//                 //         //   log.fatal("ROUND Sealed!!");
//                 //         log.fatal("ROUND Sealed!! %s", r[].all!(a => a._mother.round_received !is null));
//                 //     }
//                 // }

//                 foreach(node_id, e; r[].enumerate) {
// //                e._mother._grounded=true;
//                     round_numbers[node_id]=r.number;
//                     if (e._mother.round_received) {
// //                    sealed_round &= (e._mother.round_received.number == r.number+1);

//                         round_received_numbers[node_id]=e._mother.round_received.number;
//                     }
//                     else {
// //                    sealed_round=false;
//                         round_received_numbers[node_id]=-1;
// //                    log.fatal("node_id=%d round=%d NO ROUND_RECEIVED !!!", node_id, r.number);
//                     }
//                     // void scrap_event(Event e) {
//                     //     if ( e ) {
//                     //         scrap_event(e._mother);
//                     //         if ( Event.callbacks ) {
//                     //             Event.callbacks.remove(e);
//                     //         }
//                     //         hashgraph.eliminate(e.fingerprint);
//                     //         e.disconnect;
//                     //         e.destroy;
//                     //     }
//                     // }
//                     // scrap_event(e._mother);
//                     // if ( e ) {
//                     //     assert(e._mother is null);
//                     // }
//                 }
//             }
        }
        Round _lowest=lowest;
//        version(none)
        if ( _lowest ) {
            local_scrap(_lowest);
            _lowest.__grounded=true;
            log("Round scrapped");
        }
    }

    // static uint decided_count() nothrow {
    //     return _decided_count;
    // }

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
        Round last_round;
        Round last_decided_round;
        HashGraphI hashgraph;

        @disable this();

        this(HashGraphI hashgraph) pure nothrow {
            this.hashgraph=hashgraph;
            last_decided_round = last_round = new Round(null, hashgraph.node_size, -1);
        }

        @nogc
        uint cached_count() const pure nothrow {
            uint _cached_count(const Round r, const uint i=0) pure nothrow {
                if (r) {
                    return _cached_count(r._previous, i+1);
                }
                return i;
            }
            return _cached_count(last_round);
        }

        uint node_size() const pure nothrow
            in {
                assert(last_round, "Last round must be initialized before this function is called");
            }
        do {
            return cast(uint)(last_round._events.length);

        }

        void next_round(Event e)
            in {
                assert(last_round, "Base round must be created");
                assert(last_decided_round, "Last decided round must exist");
                assert(e, "Event must create before a round can be added");
                assert(e._round is null, "Round has already been added");
            }
        do {
            log.error("isEva %s (last_round is null) = %s", e.isEva, (last_round is null));
            scope (exit) {
                assert(e._round !is null);
                e._round.add(e);
            }
            // if (last_round is null) {
            //     log.error("last_round is null e.node_size=%d", e.node_size);
            //     e._round = last_decided_round = last_round = new Round(null, e.node_size, -1);
            //     last_decided_round._events[e.node_id] = e;
            //     if (Event.callbacks) {
            //         Event.callbacks.round_seen(e);
            //     }
            // }
            // else
            if (e.isEva) {
                log.error("e.isEva");
                assert(last_decided_round);
                for(Round r=last_decided_round; r !is null; r = r._next) {
                    log.error("e.isEva e.node_id = %d r._events.length=%d e.fingerprint=%s", e.node_id, r._events.length, e.fingerprint.cutHex);
                    if (r._events[e.node_id] is null) {
                        log.error("e.isEva (r is null) = %s", r is null);

                        e._round = r;
                        break;
                    }
                }
                assert(e._round !is null);
                log.error("EVA (e._round is null) = %s", e._round is null);
            }
            else {
                if (e._round && e._round._next) {
                    log.error("EVA Defined");
                    e._round = e._round._next;
                    assert(e._round !is null);
                }
                else {
                    log.error("EVA create round");
                    e._round = last_round = new Round(last_round, hashgraph.node_size, last_round.number+1);
                    if (Event.callbacks) {
                        Event.callbacks.round_seen(e);
                    }
                    assert(e._round !is null);
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

        void dump() const nothrow {
            log("ROUND dump");
            void _dump(const Round r) nothrow {
                if (r) {
                    log("\tRound %d %s", r.number, decided(r));
                    _dump(r._previous);
                }
            }
            return _dump(last_decided_round);
        }

        void check_coin_round() {
            if ( coin_round_distance >= coin_round_limit ) {
                // Force a coin round
                // Round undecided=undecided_round;
                // undecided.decide;
                log.trace("Coin round %d", last_decided_round._next.number);
                decide;
                if ( Event.callbacks ) {
                    Event.callbacks.coin_round(last_decided_round);
                }
            }
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

        private void decide() {
            auto round_to_be_decided = last_decided_round._next;
            scope(success) {
                last_decided_round = round_to_be_decided;
                if ( Event.callbacks ) {
                    Event.callbacks.round_decided(hashgraph.rounds);
                }
            }
            round_to_be_decided.consensus_order(hashgraph);
        }

        @nogc
        bool check_decided_round_limit() pure const nothrow {
            return cached_decided_count > total_limit;
        }

        void check_decided_round()
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
                            BitArray strong_seeing_mask;
                            bitarray_clear(strong_seeing_mask, node_size);
                            /// See through the next round
                            auto next_round = e._round._next;
                            const(BitArray) calc_seeing_mask() @trusted pure nothrow {
                                BitArray result;
                                result.length=node_size;
                                foreach(seeing_node_id; e._witness._seen_in_next_round_mask.bitsSet) {
                                    if (next_round._events[seeing_node_id]) {
                                        result |= next_round._events[seeing_node_id]._witness._seen_in_next_round_mask;
                                    }
                                }
                                return result;
                            }

                            const seeing_mask=calc_seeing_mask;

                            bool famous_search(ref const(BitArray) seeing_mask,
                                ref scope const(Round) current_round) @trusted {
                                if (current_round) {
                                    const seeing_through=seeing_mask.isMajority;
                                    BitArray next_seeing_mask;
                                    next_seeing_mask.length=node_size;
                                    //bitarray_clear(next_seeing_mask, node_size);
                                    foreach(next_node_id, e; current_round._events) {
                                        if (seeing_mask[next_node_id] && e) {
                                            next_seeing_mask |= next_round._events[next_node_id]._witness._seen_in_next_round_mask;
                                            if (seeing_through && next_seeing_mask.isMajority) {
                                                return true;
                                            }
                                        }
                                    }
                                    return famous_search(next_seeing_mask, current_round._next);
                                }
                                return false;
                            }
                            e._witness._famous = seeing_mask.isMajority && famous_search(seeing_mask, next_round._next);
                            if (e._witness.famous) {
                                famous_votes++;
                                if (Event.callbacks) {
                                    Event.callbacks.famous(e);
                                }
                            }
                        }
                    }
                }
                if (last_decided_round._next._event_counts == famous_votes) {
                    decide;
                }
            }
        }
    }

}

@safe
class Event {
    import tagion.basic.ConsensusExceptions;
    protected alias check=Check!EventConsensusException;
    protected static uint _count;
    static uint count() nothrow {
        return _count;
    }

    protected enum _params = [
        "altitude",   // altitude
        Keywords.pubkey,
        Keywords.signature,
        // "pubkey",
        // "signature" Keywords.,
        "type",
        "event",
        "ebody",
        "epack",
        "fingerprint"

        ];

    mixin(EnumText!("Params", _params));
// FixMe: CBR 19-may-2018
// Note pubkey is redundent information
// The node_id should be enought this will be changed later
    this(
        const(EventPackage) epack,
        HashGraphI hashgraph,
//        immutable(ubyte[]) signature,
//        Pubkey pubkey,
//        const uint node_id,
        ) {
        event_package=epack;
        this.node_id=hashgraph.nodeId(epack.pubkey);
        this.id=next_id;
        _count++;

        if ( isEva ) {
            // If the event is a Eva event the round is undefined
            BitArray round_mask;
            bitarray_clear(round_mask, hashgraph.node_size);
            _witness = new Witness(this, round_mask);
            assert(_round is null);
            hashgraph.rounds.next_round(this);
            log.error("#### lastround is null %s", hashgraph.rounds.last_round is null);
            //Round.seed_round(node_size);
            //_round.add(this);
            _received_order=-1;
        }


    }

    ~this() {
        _count--;
    }

    // @nogc
    // const(Witness) witness() pure const nothrow {
    //     return _witness;
    // }


    @safe
    static class Witness {
        protected static uint _count;
        @nogc static uint count() nothrow {
            return _count;
        }
        private {
            immutable(BitArray) _seeing_witness_in_previous_round_mask; /// The maks resulting to this witness
//            Event _previous_witness_event;
            BitArray _famous_decided_mask;
            BitArray _strong_seeing_mask;
            // This vector shows what we can see in the previous witness round
///            // Round seeing masks from next round
            BitArray _seen_in_next_round_mask;
            uint     _round_seen_count;
            uint     _famous_votes;
            bool     _famous_decided;
            bool _famous;
        }
        // @trustes
        // this(Event owner_event, Event previous_witness_event,
        //     ref const(BitArray) round_witness_mask) pure nothrow {
        //     _owner_event = owner_event;
        //     _previous_witness_event = previous_witness_event;
        //     _count++;
        // }

        @trusted
        this(Event owner_event, ref const(BitArray) seeing_witness_in_previous_round_mask) nothrow
        in {
            assert(seeing_witness_in_previous_round_mask.length > 0);
            assert(owner_event);
        }
        do {
            _seeing_witness_in_previous_round_mask=cast(immutable)seeing_witness_in_previous_round_mask.dup;
            _famous_decided_mask.length=node_size;
//            _previous_witness_event=previous_witness_event;
            //_round_seen_mask.length=node_size;
            _count++;
        }

        ~this() {
            _count--;
        }

        @nogc
        uint node_size() pure const nothrow {
            return cast(uint)_strong_seeing_mask.length;
        }

        // @nogc
        // inout(Event) previous_witness_event() inout pure nothrow {
        //     return _previous_witness_event;
        // }

        @nogc
        ref const(BitArray) strong_seeing_mask() pure const nothrow {
            return _strong_seeing_mask;
        }

        @trusted
        private void seen_from_previous_round(Event owner_event) nothrow
            in {
                assert(owner_event._witness is this, "The owner_event does not own this witness");
                assert(owner_event._round, "Event must have a round");
                assert(owner_event._round._previous, "The round of this witness must have a previous round");
            }
        do {
            scope(success) {
                // The witness mask for a witness is set to node_id
                owner_event._witness_mask.bitarray_clear(owner_event._witness_mask.length);
                owner_event._witness_mask[owner_event.node_id] = true;
            }
            foreach(privous_witness_node_id, e; owner_event._round._previous._events) {
                if (owner_event._witness_mask[privous_witness_node_id]) {
                    e._witness._seen_in_next_round_mask[privous_witness_node_id] = true;
                }
            }
        }

        @nogc
        ref const(BitArray) round_seen_mask() pure const nothrow {
            return _seeing_witness_in_previous_round_mask;
        }

        version(none)
        @trusted
        package void round_seen_vote(const uint node_id) {
            if ( !_round_seen_mask[node_id] ) {
                _round_seen_mask[node_id] = true;
                _round_seen_count++;
            }
        }

        version(none)
        @trusted
        package void famous_vote(ref const(BitArray) strong_seeing_mask) {
            if ( !_famous_decided ) {
                const BitArray vote_mask=strong_seeing_mask & _round_seen_mask;
                immutable votes=countVotes(vote_mask);
                if ( votes > _famous_votes ) {
                    _famous_votes = votes;
                }
                if ( isMajority(votes, node_size ) ) {
                    _famous_decided_mask|=vote_mask;
                    if ( _famous_decided_mask == _round_seen_mask ) {
                        // Famous decided if all the round witness has been seen with majority
                        _famous_decided=true;
                    }
                }
            }
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
        bool famous() pure const nothrow {
            return isMajority(_famous_votes, node_size);
        }

    }

    alias Event delegate(immutable(ubyte[]) fingerprint, Event child) @safe Lookup;
    alias bool delegate(Event) @safe Assign;
    static EventMonitorCallbacks callbacks;
    static EventScriptCallbacks scriptcallbacks;
//    import std.stdio;
//    static File* fout;
//    immutable(ubyte[]) signature;
//    immutable(Buffer) pubkey;
    @nogc
    immutable(Pubkey) channel() pure const nothrow {
        return event_package.pubkey;
    }
//    alias event_body=event_package.event_body ;
    // alias pubkey=event_package.pubkey;
    // alias signature=event_package.signature;

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
    const(EventPackage) event_package;

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
        uint _witness_votes;
        BitArray _witness_mask;
        uint     _mark;
        static uint _marker;
    }

    private {
        Round  _round;
        Round  _round_received;
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

    @nogc @property
    private uint node_size() pure const nothrow {
        return cast(uint)witness_mask.length;
    }

    immutable uint id;
    protected {
        static uint id_count;


        bool _strongly_seeing_checked;
        bool _loaded;
        // This indicates that the hashgraph aften this event
        bool _forked;
        bool _grounded;
    }

    @nogc @property
    private static immutable(uint) next_id() nothrow {
        if ( id_count == id_count.max ) {
            id_count = 1;
        }
        else {
            id_count++;
        }
        return id_count;
    }

    HiBON toHiBON() const{
        auto hibon=new HiBON;
        foreach(i, m; this.tupleof) {
            enum member_name=basename!(this.tupleof[i]);
            alias Type=typeof(this.tupleof[i]);
            static if ( member_name == basename!(event_package) ) {
                enum name=Params.epack;
            }
            else {
                enum name=member_name;
            }
            static if ( name[0] != '_' ) {
                static if ( __traits(compiles, m.toHiBON) ) {
                    hibon[name]=m.toHiBON;
                }
                else {
                    hibon[name]=cast(TypedefType!Type)m;
                }
            }
        }
        return hibon;
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

    private bool check_if_round_was_received(const uint number_of_famous, Round received) {
        if ( !_round_received ) {
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

    // This function markes the witness in the previous round which
    // See this the witness
//    @trusted // FIXME: trusted should be removed after debugging
    version(none)
    package bool collect_famous_votes() {
        bool result;
        void collect_votes(Round previous_round) @safe {
            if ( previous_round && !previous_round._decided ) {
                collect_votes( previous_round._previous );
                foreach(seen_node, e; previous_round) {
                    e._witness.famous_vote(_witness.strong_seeing_mask);
                }
                if ( previous_round._previous ) {
                    if ( ( previous_round is Round.undecided_round ) && previous_round.can_be_decided ) {
                        previous_round.decide;
                        result = true;
                    }
                }
            }
        }
        if ( _witness && !isEva  ) {
            collect_votes(_round._previous);
        }
        return result;
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
    Round round() nothrow
        in {
            if ( !_grounded && motherExists ) {
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

    private uint witness_votes(immutable uint node_size) {
        witness_mask(node_size);
        return _witness_votes;
    }

    @nogc
    uint witness_votes() pure const nothrow
        in {
            assert(is_witness_mask_checked);
        }
    do {
        return _witness_votes;
    }

    @nogc
    bool is_witness_mask_checked() pure const nothrow {
        return _witness_mask.length != 0;
    }


    package ref const(BitArray) witness_mask(immutable uint node_size) {
        ref BitArray check_witness_mask(Event event, immutable uint level=0) @trusted
            in {
                assert(event);
            }
        do {
            if ( !event.is_witness_mask_checked ) {
                bitarray_clear(event._witness_mask, node_size);
                if ( event._witness ) {
                    if ( !event._witness_mask[event.node_id] ) {
                        event._witness_votes++;
                    }
                    event._witness_mask[event.node_id]=true;
                }
                else {
                    if ( event.mother ) {
                        auto mask=check_witness_mask(event._mother, level+1);
                        if ( mask.length < event._witness_mask.length ) {
                            mask.length = event._witness_mask.length;
                        }
                        else if ( mask.length > event._witness_mask.length ) {
                            event._witness_mask.length = mask.length;
                        }

                        event._witness_mask|=mask;

                    }
                    if ( event.father ) {
                        auto mask=check_witness_mask(event._father, level+1);
                        if ( mask.length < event._witness_mask.length ) {
                            mask.length = event._witness_mask.length;
                        }
                        else if ( mask.length > event._witness_mask.length ) {
                            event._witness_mask.length = mask.length;
                        }

                        event._witness_mask|=mask;
                    }
                    event._witness_votes=countVotes(_witness_mask);
                }
            }
            bitarray_change(event._witness_mask, node_size);
            return event._witness_mask;
        }
        return check_witness_mask(this);
    }


    @nogc
    ref const(BitArray) witness_mask() pure const nothrow
        in {
            assert(is_witness_mask_checked);
        }
    do {
        return _witness_mask;
    }

    @nogc
    const(Witness) witness() pure const nothrow {
        return _witness;
    }

    // @nogc
    // package Witness witness() pure nothrow {
    //     return _witness;
    // }

    version(none)
    @trusted
    package void strongly_seeing(Event previous_witness_event, ref const(BitArray) strong_seeing_mask)
    in {
        assert(!_strongly_seeing_checked);
        assert(_witness_mask.length != 0);
        assert(previous_witness_event);
    }
    do {
        bitarray_clear(_witness_mask, node_size);
        _witness_mask[node_id]=true;
        if ( _father && _father._witness !is null ) {
            _witness_mask|=_father.witness_mask;
        }
        _witness=new Witness(this, previous_witness_event, strong_seeing_mask);
        next_round;
        _witness.seeing_previous_round(this);
        if ( callbacks ) {
            callbacks.strongly_seeing(this);
            callbacks.round(this);
        }
    }

    version(none)
    private void next_round() {
        // The round number is increased by one
        _round=Round(mother._round.number+1);
        // Event added to round
        _round.add(this);

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


    @nogc
    immutable(Pubkey) pubkey() const pure nothrow {
        return event_package.pubkey;
    }


    immutable size_t node_id;
// Disconnect the Event from the graph
    version(none)
    @trusted
    package void disconnect() {
//        version(none) {
        // scope(exit) {

        // }
//        if (_round_received &&
        if (isEva) {
            log.trace("Remove Eva Event id=%d", id);
            _round.remove(this);
            if ( _round.empty ) {
                if ( Event.callbacks ) {
                    Event.callbacks.remove(_round);
                }
                // if (_round._previous !is null) {
                //     log.fatal("_round._previous = %d", _round._previous.number);
                // }
                // log.fatal("Disconnect round %d %s", _round.number, _round._previous is null);
                _round.disconnect;
                //_round.destroy;
                //_round=null;
            }
            //h.eliminate(fingerprint);
            this.destroy;
        }
        else {
            bool remove_it=(_daughter._round_received) && (((_daughter._round_received.number-_round_received.number) >= 0));
            log.trace("Remove Event id=%d %s", id, remove_it);
            if ((_son) && remove_it) {
                remove_it=(_son._round_received) && (((_son._round_received.number-_round_received.number) >= 0));
            }
            if (remove_it) {
                if (_mother) {
                    _mother.disconnect;
                }
                scope(exit) {
                    _daughter._mother=null;
                    if (_son) {
                        _son._father=null;
                    }
                    _father=_mother=null;
                    //h.eliminate(fingerprint);
                    this.destroy;
                }
                if ( _witness ) {
                    _round.remove(this);
                    if ( _round.empty ) {
                        if ( Event.callbacks ) {
                            Event.callbacks.remove(_round);
                        }
                        _round.disconnect;
                    }
                    _witness.destroy;
                }
            }
        }
    }

    @nogc
    bool grounded() pure const nothrow {
        return _grounded || (_mother is null);
    }

    @nogc
    static int received_order_max(const(Event) mother, const(Event) father) pure nothrow {
        int result=mother._received_order;
        if ( father && ( ( mother._received_order - father._received_order ) < 0 ) ) {
            result=father._received_order;
        }
        result++;
        if ( result < 0 ) {
            result=0;
        }
        return result;
    }


    version(none)
    Event mother(RequestNet request_net) {
        Event result;
        result=mother!true(request_net);
        if ( !result && motherExists ) {
            request_net.request(mother_hash);
            result=mother(request_net);
        }
        return result;
    }

    @nogc
    int received_order() pure const nothrow {
        return _received_order;
    }

    // +++
    @trusted
    private const(BitArray) calc_witness_mask(const size_t size)
        in {
            assert(_mother);
        }
    do {
        BitArray result;
        result.bitarray_clear(size);
        if (_father) {

            const round_diff=_round.number - _father._round.number;
            if (round_diff == 0) {
                result = _father._witness_mask.dup;
            }
            else if (round_diff == -1) {
                bitarray_clear(result, node_size);
                foreach(node_id, e; _father._round) {
                    if ( e && _father._witness_mask[node_id] ) {
                        result |= e._witness._strong_seeing_mask;
                    }
                }
            }
            else if (round_diff < 0) {
                bitarray_clear(result, _father.node_size);
                foreach(node_id, e; _father._round) {
                    if ( e && _father._witness_mask[node_id] ) {
                        result |= e.calc_witness_mask(size);
                    }
                }
            }
            else {
                assert(0, "fixme(cbr): No solution jet for rounf higher than the current event");
            }
            result = _mother._witness_mask | result;
        }
        else {
            result = _mother._witness_mask;

        }
        return result;
    }


    @trusted
    protected void connect(HashGraphI hashgraph) {
        if (!connected) {
            scope(exit) {
                hashgraph.front_seat(this);
            }
            _mother = register(hashgraph, event_package.event_body.mother);
            if (_mother) {
                check(!_daughter, ConsensusFailCode.EVENT_FORK);
                _mother._daughter = this;
                _father = register(hashgraph, event_package.event_body.father);
                if (_father) {
                    check(!_father._son, ConsensusFailCode.EVENT_FORK);
                    _father._son = this;
                    _witness_mask = _mother._witness_mask | _father._witness_mask;
                }
                else {
                    _witness_mask = _mother._witness_mask;
                }
                _received_order = received_order_max(_mother, _father);
                _round = _mother._round;
                assert(!hashgraph.rounds.decided(_round),
                            "Fixme(cbr):This node is way behind we need to find a solution");
                const calc_mask = calc_witness_mask(hashgraph.node_size);
                if ( calc_mask.isMajority ) {
                    // Witness detected
                    hashgraph.rounds.next_round(this);
                    _witness = new Witness(this, calc_mask);
                    // Set the witness seen from the previous round
                    _witness.seen_from_previous_round(this);
                    // Search for famous
                    hashgraph.rounds.check_decided_round;
                }
            }
            if (Event.callbacks) {
                Event.callbacks.create(this);
            }
        }
    }

// +++
    static Event register(HashGraphI hashgraph, scope const(Buffer) fingerprint) {
        Event event;
        if (fingerprint) {
            event = hashgraph.lookup(fingerprint);
            if ( event ) {
                event.connect(hashgraph);
            }
        }
        return event;
    }

    bool connected() {
        return (_mother !is null) || isEva;
    }

    @nogc
    package Event mother_raw() pure nothrow
        in {
            assert((_mother !is null) || (event_package.event_body.mother is null));
        }
    do {
        return _mother;
    }

    // +++
    version(none)
    protected Event mother(HashGraphI hashgraph) {
        if (!_mother && !isEva) {
            _mother=hashgraph.register(mother_hash);
            _father=father(hashgraph);
        }
        return _mother;
    }

    version(none)
    protected Event father(HashGraphI hashgraph) {
        if (!_father) {
            _father=hashgraph.register(father_hash);
        }
        return _father;
    }

    version(none)
    protected Event mother(bool ignore_null_check)(RequestNet request_net)
    out(result) {
        static if ( !ignore_null_check) {
            if ( mother_hash ) {
                assert(result, "the mother is not found");
            }
        }
    }
    do {
        if ( _mother is null ) {
            _mother = request_net.register(mother_hash);
            if ( _mother ) {
                _received_order=_mother.received_order_max(_father);
            }
        }
        return _mother;
    }

    const(Event) mother() const pure nothrow
    in {
        assert(!_grounded, "Mother can't be accessed becuase this event is grounded");
        if ( event_package.event_body.mother ) {
            assert(_mother);
            assert( (altitude-_mother.altitude) == 1 );
        }
    }
    do {
        return _mother;
    }

    version(none)
    package Event mother_raw() nothrow pure
    in {
        if ( mother_hash ) {
            assert(_grounded || _mother);
            if (_mother) {
                assert( (altitude-_mother.altitude) == 1 );
            }
        }
    }

    do {
        return _mother;
    }

    version(none)
    protected Event father_y(bool ignore_null_check)(RequestNet request_net)
    out(result) {
        static if ( !ignore_null_check) {
            if ( father_hash ) {
                assert(result, "the father is not found");
            }
        }
        assert(!_grounded, "Father can't be accessed becuase this event is grounded");
    }
    do {
        if ( _father is null ) {
            _father = request_net.lookup(father_hash);
            if ( _father ) {
                _received_order=_father.received_order_max(_mother);
            }
        }
        return _father;
    }

    version(none)
    Event father_x(RequestNet request_net) {
        Event result;
        result=father_y!true(request_net);
        if ( !result && fatherExists ) {
            request_net.request(father_hash);
            result=father_x(request_net);
        }
        return result;
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

    version(none)
    @nogc
    package Event father_raw() pure nothrow
    in {
        if ( father_hash ) {
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

    package void daughter(Event c)
    in {
        if ( _daughter !is null ) {
            assert( c !is null, "Daughter can not be set to null");
        }
    }
    do {
        if ( _daughter && (_daughter !is c) ) {
            forked = true;
        }
        else {
            _daughter=c;
            if ( callbacks ) {
                callbacks.daughter(this);
            }

        }
    }

    @nogc
    package Event son() pure nothrow {
        return _son;
    }

    @nogc
    const(Event) son() const pure nothrow {
        return _son;
    }

    package void son(Event c)
    in {
        if ( _son !is null ) {
            assert( c !is null, "Son can not be set to null");
        }
    }
    do {
        if ( _son && (_son !is c) ) {
            forked=true;
        }
        else {
            _son=c;
            if ( callbacks ) {
                callbacks.son(this);
            }
        }
    }

    version(none)
    @nogc
    package void loaded() nothrow
    in {
        assert(!_loaded, "Event can only be loaded once");
    }
    do {
        _loaded=true;
    }

    version(none)
    @nogc
    bool is_loaded() const pure nothrow {
        return _loaded;
    }

    version(none)
    @nogc
    immutable(ubyte[]) father_hash() const pure nothrow {
        return event_package.event_body.father;
    }

    version(none)
    @nogc
    immutable(ubyte[]) mother_hash() const pure nothrow {
        return event_package.event_body.mother;
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
    bool motherExists() const pure nothrow {
        //     in {
        //         assert(!_grounded, "This function should not be used on a grounded event");
        //     }
        // do {
        return event_package.event_body.mother !is null;
    }

    version(none)
    @nogc
    bool fatherExists() const pure nothrow {
        return event_package.event_body.father !is null;
    }

// is true if the event does not have a mother or a father
    @nogc
    bool isEva() pure const nothrow {
        //     in {
        //         assert(!_grounded, "This function should not be used on a grounded event");
        //     }
        // do {
        return event_package.event_body.isEva; //!motherExists;
    }

    @nogc
    immutable(Buffer) fingerprint() const pure nothrow {
        // in {
        //     assert(_fingerprint, "Hash has not been calculated");
        // }
        // do {
        return event_package.fingerprint;
    }

    int opApply(scope int delegate(immutable uint level,
            immutable bool mother ,const(Event) e) @safe dg) const {
        int iterator(const(Event) e, immutable bool mother=true, immutable uint level=0) @safe {
            int result;
            if ( e ) {
                result = dg(level, mother, e);
                if ( result == 0 ) {
                    iterator(e.mother, true, level+1);
                    iterator(e.father, false, level+1);
                }
            }
            return result;
        }
        return iterator(this);
    }

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
