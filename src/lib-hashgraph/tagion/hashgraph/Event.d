module tagion.hashgraph.Event;

import std.datetime;   // Date, DateTime
import tagion.utils.BSON : HBSON, Document;

import tagion.crypto.Hash;

import tagion.hashgraph.GossipNet;
import tagion.hashgraph.ConsensusExceptions;
import std.conv;
import std.bitmanip;

import std.format;

import tagion.Base : this_dot, basename, Pubkey, Buffer, bitarray_clear, bitarray_change, countVotes, isMajority;

import tagion.Keywords;

@safe
void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) {
    if (!flag) {
        throw new EventConsensusException(code, file, line);
    }
}

// Returns the highest altitude
@safe
int highest(int a, int b) pure nothrow {
    if ( higher(a,b) ) {
        return a;
    }
    else {
        return b;
    }
}

// Is a higher or equal to b
@safe
bool higher(int a, int b) pure nothrow {
    return a-b > 0;
}

@safe
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
struct EventBody {
    immutable(ubyte)[] payload; // Transaction
    immutable(ubyte)[] mother; // Hash of the self-parent
    immutable(ubyte)[] father; // Hash of the other-parent
    int altitude;

    ulong time;
    invariant {
        if ( (mother.length != 0) && (father.length != 0 ) ) {
            assert( mother.length == father.length );
        }
    }

    this(
        immutable(ubyte)[] payload,
        Buffer mother,
        Buffer father,
        immutable ulong time,
        immutable int altitude) inout {
        this.time      =    time;
        this.altitude  =    altitude;
        this.father    =    father;
        this.mother    =    mother;
        this.payload   =    payload;
        consensus();
    }

    this(immutable(ubyte)[] data) inout {
        auto doc=Document(data);
        this(doc);
    }

    bool isEva() pure const nothrow {
        return (mother.length == 0);
    }

    this(Document doc, RequestNet request_net=null) inout {
        foreach(i, ref m; this.tupleof) {
            alias typeof(m) type;
            enum name=basename!(this.tupleof[i]);
            if ( doc.hasElement(name) ) {
                static if ( name == mother.stringof || name == father.stringof ) {
                    if ( request_net ) {
                        immutable event_id=doc[name].get!uint;
                        this.tupleof[i]=request_net.eventHashFromId(event_id);
                    }
                    else {
                        this.tupleof[i]=(doc[name].get!type).idup;
                    }
                }
                else {
                    static if ( is(type : immutable(ubyte[])) ) {
                        this.tupleof[i]=(doc[name].get!type).idup;
                    }
                    else {
                        this.tupleof[i]=doc[name].get!type;
                    }
                }
            }
        }
        consensus();
    }

    void consensus() inout {
        if ( mother.length == 0 ) {
            // Seed event first event in the chain
            check(father.length == 0, ConsensusFailCode.NO_MOTHER);
        }
        else {
            if ( father.length != 0 ) {
                // If the Event has a father
                check(mother.length == father.length, ConsensusFailCode.MOTHER_AND_FATHER_SAME_SIZE);
            }
            check(mother != father, ConsensusFailCode.MOTHER_AND_FATHER_CAN_NOT_BE_THE_SAME);
        }
    }

    HBSON toBSON(const(Event) use_event=null) const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name]=m.toBSON;
            }
            else {
                bool include_member=true;
                static if ( __traits(compiles, m.length) ) {
                    include_member=m.length != 0;
                }
                if ( include_member ) {
                    if ( use_event && name == basename!mother &&  use_event.mother ) {
                        bson[name]=use_event.mother.id;
                    }
                    else if ( use_event && name == basename!father && use_event.father ) {
                        bson[name]=use_event.father.id;
                    }
                    else {
                        bson[name]=m;
                    }
                }
            }
        }
        return bson;
    }

    @trusted
    immutable(ubyte[]) serialize(const(Event) use_event=null) const {
        return toBSON(use_event).serialize;
    }

}


@safe
class HashGraphException : Exception {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

@safe
interface EventCallbacks {
    void create(const(Event) e);
    void witness(const(Event) e);
    void witness_mask(const(Event) e);
//    void witness2_mask(const(Event) e);
    void strongly_seeing(const(Event) e);
//    void strongly2_seeing(const(Event) e);
    void strong_vote(const(Event) e, immutable uint vote);
//    void strong2_vote(const(Event) e, immutable uint vote);
    void round_mask(const(Event) e);
    void round_seen(const(Event) e);
    void looked_at(const(Event) e);

    void famous(const(Event) e);
//    void famous_mask(const(Event) e);
    void round(const(Event) e);
    void forked(const(Event) e);
    void remove(const(Event) e);
//    void famous_votes(const(Event) e);
    void iterations(const(Event) e, const uint count);
}

@safe
class Round {
    private Round _previous;
    // This indicates wish events belongs to this round
    // private BitArray nodes_mask;
    // Counts the number of nodes in this round
    immutable int number;
    private bool _decided;

    private BitArray _looked_at_mask;
    private uint _looked_at_count;
//    private uint _famous_events_decided_count;
//    private uint _activte_events_count;
    static int increase_number(const(Round) r) {
        return r.number+1;
    }

    private Event[] _events;
    private static Round _rounds;

    static void dump() {
        Event.fout.writefln("ROUND dump");
        for(Round r=_rounds; r !is null; r=r._previous) {
            Event.fout.writefln("\tRound %d %s", r.number, r.famous_decided);
        }
    }

    bool lessOrEqual(const Round rhs) pure const {
        return (number - rhs.number) <= 0;
    }

    uint node_size() pure const nothrow {
        return cast(uint)_events.length;
    }

    private this(Round r, const uint node_size, immutable int round_number) {
        _previous=r;
        number=round_number;
        _events=new Event[node_size];
        bitarray_clear(_looked_at_mask, node_size);
    }

    private Round next_consecutive() {
        _rounds=new Round(_rounds, node_size, _rounds.number+1);
        return _rounds;
    }

    // Used to make than an witness in the next round at the node_id has looked at this round
    @trusted
    package void looked_at(const uint node_id) {
        if ( !_looked_at_mask[node_id] ) {
            _looked_at_mask[node_id]=true;
            _looked_at_count++;
        }
    }

    // Checked if all active nodes/events in this round has beend looked at
    bool seeing_completed() const pure nothrow {
        return _looked_at_count == node_size;
    }

    ref const(BitArray) looked_at_mask() pure const nothrow {
        return _looked_at_mask;
    }

    uint looked_at_count() pure const nothrow {
        return _looked_at_count;
    }

    package static Round seed_round(const uint node_size) {
        if ( _rounds is null ) {
            _rounds = new Round(null, node_size, -1);
        }
        // Use the latest round as seed round
        return _rounds;
    }

    static Round opCall(const int round_number)
        in {
            assert(_rounds, "Seed round has to exists before the operation is used");
        }
    do {
        Round find_round(Round r) {
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

    package int opApply(scope int delegate(const uint node_id, Event event) @safe dg) {
        int result;
        foreach(uint node_id, e; _events) {
            if ( e ) {
                result=dg(node_id, e);
                if ( result ) {
                    break;
                }
            }
        }
        return result;
    }

    int opApply(scope int delegate(const uint node_id, const(Event) event) @safe dg) const {
        int result;
        foreach(uint node_id, e; _events) {
            if ( e ) {
                result=dg(node_id, e);
                if ( result ) {
                    break;
                }
            }
        }
        return result;
    }

    void add(Event event)
        in {
            // version(DECIDED_PROBLEM) {
            //     assert(!_decided, "FIXME: An event has been added after this round has been decided!");
            // }
//            assert(event.witness, "Event added to a round should be a witness");
            assert(_events[event.node_id] is null, "Evnet should only be added once");
        }
    do {
//        version(none) {
//         version(DECIDED_PROBLEM) {
//             // empty
//         }
//         else {
//             if ( _decided ) {
//                 Event.fout.writeln("--------------- ------------- ----------");
//                 Round.dump;
//                 Round.undo_decision(this);
//                 Round.dump;
// //                _decided=false;
//             }
//         }
        _events[event.node_id]=event;
    }

    inout(Event) event(const uint node_id) pure inout {
        return _events[node_id];
    }

    // Whole round decided
    package bool famous_decided() pure const nothrow {
        return _decided;
//        import std.stdio;
    }

    package bool update_decision()  {
        if ( !_decided && !seeing_completed ) {
            if ( _previous ) {
                foreach(node_id, e; this) {
                    if ( e._witness.famous_decided ) {
                        _decided=true;
                    }
                    else {
                        _decided=false;
//                        writefln("Not decide break at %d", node_id);
                        break;
                    }
                }
            }
            else {
                 _decided=true;
            }
        }
        return _decided;
    }

    void ground(H)(H h) {
        foreach(node_id, ref e; this) {
            e.ground(h);
        }
        void grounding(Round r) @safe {
            if ( r ) {
                if ( r._previous !is this ) {
                    grounding(r._previous);
                }
                r._previous=null;
            }
        }
        grounding(_rounds);
    }
    // Return true if the event on node_id has been decided
    // @trusted
    // bool famous_decided(const uint node_id) pure const nothrow {
    //     return _famous_events_decided[node_id];
    // }

    // @trusted
    // package void famous_decide(const uint node_id) {
    //     if ( !_famous_events_decided[node_id] ) {
    //         _famous_events_decided[node_id]=true;
    //         _famous_events_decided_count++;
    //     }
    // }

    // Find collecting round from which the famous votes is collected from the previous round
    package Round undecided_round() {
        Round search(Round r) {
            if ( r && r._previous && !r._previous.famous_decided ) {
                return search(r._previous);
            }
            return r;
        }
        Round result=search(_previous);
        if ( result && !result.famous_decided ) {
            return result;
        }
        return null;
    }

    version(none)
    package static void undo_decision(Round until) {
        import std.stdio;
        void undo(Round r) {
            if ( r ) {
                if ( r._decided ) {
                    Event.fout.writefln("Undo decides for round %d", r.number);
                }
                r._decided = false;
                if ( r !is until ) {
                    undo(r._previous);
                }
            }
        }
        undo(_rounds);
    }

    void disconnect(Event event) {
        _events[event.node_id]=null;
    }

    // bool famous_decided() const pure nothrow
    //     in {
    //         assert(_famous_decided_votes.length > 0);
    //     }
    // do {
    //     return _famous_decided_votes.length == _famous_decided_votes_count;
    // }

    // @trusted
    // void famous_decide(const uint node_id)
    //     in {
    //         assert(!isUndefined, "The state of the undefined round is not allowed to be changed");
    //     }
    // do {
    //     if ( !_famous_decided_votes[node_id] ) {
    //         _famous_decided_votes[node_id] = true;
    //         _famous_decided_votes_count++;
    //     }
    // }

    // bool isUndefined() const nothrow {
    //     return this is _undefined;
    // }

    // static Round undefined() nothrow {
    //     return _undefined;
    // }

    // The function collectes votes on the witness in this round which are seen by the seen_by_node_id
    // void seen(const uint node_id, const uint seen_by_node_id)
    //     in {
    //         assert(_events[node_id] !is null, "This round does not have an event in from this node");
    //     }
    // do {
    //     pragma(msg, "typeof(_events[node_id].witness)="~typeof(_events[node_id].witness).stringof);
    //     pragma(msg, "typeof(_events[node_id].witness)="~typeof(_events[node_id].witness.seen).stringof);
    //     _events[node_id].witness.seen(seen_by_node_id);
    // }

    Round previous() pure nothrow {
        return _previous;
    }

    invariant {
        void check_round_order(const Round r, const Round p) {
            if ( ( r !is null) && ( p !is null ) ) {
                assert( (r.number-p.number) == 1, "Consecutive round-numbers has to increase by one");
                check_round_order(r._previous, p._previous);
            }
        }
        check_round_order(this, _previous);
        // bool decided_flag;
        // for(Round r=_rounds; r !is null; r=r._previous) {
        //     if ( r.famous_decided ) {
        //     }
        // }
    }
}

@safe
class Witness {
    private Event _previous_witness_event;
//    private Event _owner_event;
    private BitArray _famous_decided_mask;
    private bool     _famous_decided;
    private BitArray _seen_mask;
    private BitArray _strong_seeing_mask;
    // This vector shows what we can see in the previous witness round
    // Round seeing masks from next round
    private BitArray _round_seen_mask;
    // Mask when witness as look at the previous round
    private BitArray _seeing_previous_round_mask;

    private uint     _round_seen_count;
    private uint     _famous_votes;
//    private uint     _famous_counts;
    //   immutable uint   node_size;
    @trusted
    this(Event owner_event, Event previous_witness_event, ref const(BitArray) strong_seeing_mask)
    in {
        assert(strong_seeing_mask.length > 0);
        assert(owner_event);
    }
    do {
//        _famous_mask.length=node_size;
//        _owner_event=owner_event;
        //this.node_size=cast(uint)strong_seeing_mask.length;
        _strong_seeing_mask=strong_seeing_mask.dup;
        _seen_mask.length=node_size;
        _famous_decided_mask.length=node_size;
//        _famous_vote_mask.length=node_size;
        _previous_witness_event=previous_witness_event;

        _seeing_previous_round_mask.length=node_size;
        _round_seen_mask.length=node_size;
         // if ( !owner.isEva ) {
             // Set the witness event to next round
//             owner.next_round;
             // Seeing witness in the previous and update _round_seen_mask
             // seeing_previous_round(owner);
        // }
    }

    uint node_size() pure const nothrow {
        return cast(uint)_strong_seeing_mask.length;
    }

    Event previous_witness_event() pure nothrow {
        return _previous_witness_event;
    }

    ref const(BitArray) strong_seeing_mask() pure const nothrow {
        return _strong_seeing_mask;
    }

    @trusted
    package void seeing_previous_round(Event owner_event) {
        import std.stdio;
        void update_round_seeing(Event event, string indent="") @trusted {
            if ( event ) {
                if ( !event.visit ) {
                    // && !_seeing_previous_round_mask[event.node_id] ) {
                    // _seeing_previous_round_mask[event.node_id]=true;
                    // _seeind_previous_round_count++;

                    immutable round_distance = owner_event.round.number - event.round.number;
                    Event.fout.writefln("%snode_id=%d id=%d event.round.number %d distance=%d witness=%s",
                        indent,
                        event.node_id,
                        event.id,
                        event.round.number,
                        round_distance,
                        event.witness !is null
                        );
                    if ( event.witness ) {
                        if ( !event.witness.round_seen_completed ) {
//                        if ( !event.round.seeing_completed ) {
                                        // Marked that this witness has been looked at from the next round at node_id
                            // if ( callbacks ) {

                            // }
                            if ( round_distance == 1 ) {
                                // owner event sees witness in preivous round
                                event.witness.round_seen_vote(owner_event.node_id);
                                event.round.looked_at(owner_event.node_id);

//                            event.witness._round_seen_mask[owner_event.node_id]=true;
                                Event.fout.writefln("%s\t id=%d round_seen %s", indent, event.id, event.witness._round_seen_mask);
                                if ( Event.callbacks ) {
                                    Event.callbacks.round_seen(event);
                                    Event.callbacks.looked_at(event);
                                }
                            }
                            update_round_seeing(event.mother, indent~"  ");
                            update_round_seeing(event.father, indent~"  ");
                        }
                    }
                    else if ( round_distance  <= 1 ) {
                        Event.fout.writef("%s  ", indent);
                        foreach(seeing_node_id, e; event.round) {
                            Event.fout.writef(" %d", seeing_node_id);
                            if ( event.witness_mask[seeing_node_id] ) {
                                Event.fout.writeln("->");
//                            if ( e !is owner_event ) {
                                Event.fout.writefln("%s\t call node_id=%d id=%d witness=%s",
                                    indent, e.node_id, e.id, e.witness !is null);
                                update_round_seeing(e, indent~"  ");
//                            }
                                Event.fout.writefln("<<");

                            }
                        }

                        Event.fout.writefln("@");
                    }
                }
            }
        }
        // Update the visit marker to prevent infinity recusive loop
        Event.visit_marker++;
        Event.fout.writefln("@Owner node_id=%d id=%d round=%d",
            owner_event.node_id, owner_event.id, owner_event.round.number);
        update_round_seeing(owner_event.mother, "::");
        update_round_seeing(owner_event.father,  "::");
    }


    @trusted
    package void seen(const uint node_id) {
        if ( !_seen_mask[node_id] ) {
            _seen_mask[node_id]=true;
            _famous_votes++;
        }
    }

    ref const(BitArray) seen_mask() pure const nothrow {
        return _seen_mask;
    }

    ref const(BitArray) round_seen_mask() pure const nothrow {
        return _round_seen_mask;
    }

    ref const(BitArray) famous_decided_mask() pure const nothrow {
        return _famous_decided_mask;
    }

    @trusted
    package void round_seen_vote(const uint node_id) {
        if ( !_round_seen_mask[node_id] ) {
            _round_seen_mask[node_id] = true;
            _round_seen_count++;
        }
    }

    bool round_seen_completed() pure const nothrow {
        return _round_seen_mask.length == _round_seen_count;
    }

    // package ref const(BitArray) round_seen_mask(Event wintess_event) {
    //     if ( wintness_event.mother ) {
    //         _round_seen_mask|=
    //     }
    // }

//     package ref const(BitArray) seeing_witness_mask(Event witness_event) {
//         BitArray zeros;
//         ref const(BitArray) seeing_witness(Event event) @safe {
//             if ( event ) {
//                 if ( event.round is witness_event.round ) {
//                     Event next_wintess=Round.event(event.node_id);
//                     return next_wintess.witness.seeing_witness_mask
//                 }
//                 else {

//                 }
//             }
//             else {
//                 if ( zeros.length == 0 ) {
//                     bitarray_clear(zeros, node_size);
//                 }
//                 return zeros;
//             }
//         }
//         if ( _seeing_witness_mask.length == 0 ) {
// //            bitarray_clear(_seeing_witness_mask, node_size);
//             _seeing_witness_mask=seeing_witness(witness_event.mother).dup;
//             _seeing_witness_mask|=seeing_witness(witness_event.father);
//         }
//         return _seeing_witness_mask;
//     }
//     bool famous_decided() pure const nothrow {
// //        immutable node_size=cast(uint)_famous_decided_mask.length;
//         return node_size == _famous_counts;
//     }

    // ref const(BitArray) famous_vote_mask() pure const nothrow {
    //     return _famous_vote_mask;
    // }

    // uint famous_counts() pure const nothrow {
    //     return _famous_counts;
    // }

    // void famous_votes(const uint votes) nothrow
    //     in {
    //         assert(votes <= node_size);
    //     }
    // do {
    //     if ( _famous_votes < votes ) {
    //         _famous_votes = votes;
    //     }
    // }

    @trusted
    package void famous_vote(ref const(BitArray) strong_seeing_mask) {
//        BitArray vote_mask=strong_seeing_mask & _seen_mask;
        const BitArray vote_mask=strong_seeing_mask & _round_seen_mask;
        immutable votes=countVotes(vote_mask);
        if ( votes > _famous_votes ) {
            _famous_votes = votes;
        }
        _famous_decided_mask|=vote_mask;
        if ( countVotes(_famous_decided_mask) > 0 ) {
            _famous_decided = _famous_decided_mask == _round_seen_mask;
        }
    }

    @trusted
    bool famous_decided() pure const nothrow {
        return _famous_decided;
    }

    uint famous_votes() pure const nothrow {
        return _famous_votes;
    }

    bool famous() pure const nothrow {
//        immutable node_size=cast(uint)_famous_decided_mask.length;
        return isMajority(_famous_votes, node_size);
    }



    // ref const(BitArray) seen_mask(const uint node_id) pure const {
    //     return seen_mask[node_id];
    // }
    // @trusted
    // bool confirm_famous_vote(const uint node_id) {
    //     if ( !_famous_vote_mask[node_id] ) {
    //         _famous_vote_mask[node_id]=true;
    //         _famous_counts++;
    //         if ( _seen_mask[node_id] ) {
    //             _famous_votes++;
    //         }
    //     }
    //     return _famous_counts == _famous_vote_mask.length;
    // }

}

@safe
class Event {
    alias Event delegate(immutable(ubyte[]) fingerprint, Event child) @safe Lookup;
    alias bool delegate(Event) @safe Assign;
    static EventCallbacks callbacks;
    import std.stdio;
    static File* fout;
    // Delegate function to load or find an Event in the event pool
    // Delegate function to assign an Event to event pool
    immutable(ubyte[]) signature;
    immutable(Buffer) pubkey;
    Pubkey channel() pure const nothrow {
        return cast(Pubkey)pubkey;
    }

    // Recursive markes
    private uint _visit;
    package static uint visit_marker;
    private bool visit() {
        scope(exit) {
            _visit = visit_marker;
        }
        return (_visit == visit_marker);
    }
    // The altitude increases by one from mother to daughter
    immutable(EventBody) event_body;

    private Buffer _fingerprint;
    // This is the internal pointer to the
    private Event _mother;
    private Event _father;
    private Event _daughter;
    private Event _son;
    private bool _grounded;

    private Round  _round;
    private Round  _received_round;

    // The withness mask contains the mask of the nodes
    // Which can be seen by the next rounds witness

    private Witness _witness;
    private uint _witness_votes;
    private BitArray _witness_mask;

    private uint node_size() pure const nothrow {
        return cast(uint)witness_mask.length;
    }

    private bool _strongly_seeing_checked;

    private bool _loaded;
    // This indicates that the hashgraph aften this event
    private bool _forked;
    immutable uint id;
    private static uint id_count;
    private static immutable(uint) next_id() {
        if ( id_count == id_count.max ) {
            id_count = 1;
        }
        else {
            id_count++;
        }
        return id_count;
    }

    HBSON toBSON() const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            enum member_name=basename!(this.tupleof[i]);
            static if ( member_name == basename!(event_body) ) {
                enum name=Keywords.ebody;
            }
            else {
                enum name=member_name;
            }
            static if ( name[0] != '_' ) {
                static if ( __traits(compiles, m.toBSON) ) {
                    bson[name]=m.toBSON;
                }
                else {
                    bson[name]=m;
                }
            }
        }
        return bson;
    }

    bool isFront() pure const nothrow {
        return _daughter is null;
    }

    inout(Round) round() inout pure nothrow
    out(result) {
        assert(result, "Round should be defined before it is used");
    }
    do {
        return _round;
    }

    // int round_number() pure const nothrow
    //     in {
    //         assert(_round !is null, "Round is not set for this Event");
    //     }
    // do {
    //     return _round.number;
    // }

    bool hasRound() const pure nothrow {
        return (_round !is null);
    }

    // This function markes the witness in the previous round which
    // See this the witness
    @trusted // FIXME: remove after debug
    package void mark_round_seeing() {
        import std.stdio;

        if ( _witness && !isEva ) {
            foreach(seen_node_id, e; _round.previous) {
                fout.writefln("Search %d seeing=%s", seen_node_id,  seeing_witness(seen_node_id) );
                if ( seeing_witness(seen_node_id) ) {
                    e._witness.seen(node_id);
                    if ( callbacks ) {
                        callbacks.round_mask(e);
                    }
                    fout.writefln("mark_round_seeing node_id=%d seen_node_id=%d id=%d seen=%s decided=%s:%s votes=%d ",
                        node_id, seen_node_id, e.id, e._witness.seen_mask, e._witness.famous_decided_mask,
                        e._witness.famous_decided, e._witness.famous_votes);

                }

            }
        }
    }

    // bool famous_decided(const uint node_id) pure const
    //     in {
    //         assert(_witness, "This event is not a witness so it can not be decided if it is famous or not");
    //     }
    // do {
    //     return _round.famous
    // }

    @trusted // FIXME: trusted should be removed after debugging
    package void collect_famous_votes() {
        import std.stdio;
        if ( _witness && _round.previous && !isEva  ) {
            auto undecided=_round.undecided_round; //collecting_round;
            fout.writefln("**** Undecided %s exists", undecided  !is null);
            if ( undecided ) {
                assert(!undecided.famous_decided, "False. Undecided round is decided");

                fout.writefln("UNDECIDED ROUND %d %s", undecided.number, undecided.famous_decided);
                foreach(seen_node_id, e; undecided) {
//                    if ( !e._witness.famous_decided ) {
//                        if ( e._witness.famous ) {
                            // Masks the strongly seen witness votes in the undecided round
                            e._witness.famous_vote(_witness.strong_seeing_mask);
                            //update_decision
                            // BitArray vote_mask=_witness.strong_seeing_mask & e._witness.seen_mask;
                            // immutable votes=countVotes(vote_mask);
                            // immutable majority=isMajority(votes, node_size);
                            fout.writefln("\t\t strong=%s id=%d round=%d seen=%s votes=%s majority=%s", _witness.strong_seeing_mask,  e.id, e.round.number, e._witness.round_seen_mask, e._witness.famous_votes, e._witness.famous);

//                        }
                        if ( e._witness.famous_decided ) {
                            fout.writefln("\t\tDecided id=%d node_id=%d", e.id, seen_node_id);
//                            undecided.famous_decide(seen_node_id);
                        }
                        fout.writefln("\tcollect_famous_vote id=%d node_id=%d round=%d node_id=%d seen=%s:%s decided=%s famous=%s votes=%d",
                            e.id, e.node_id, e.round.number, seen_node_id, e._witness.seen_mask,  e._witness.famous_decided_mask, e._witness.famous_decided, e._witness.famous, e._witness.famous_votes);
                        //                  }
                }

                if ( undecided.update_decision ) {
                    fout.writefln("Round %d decided ", undecided.number);
                    if ( callbacks ) {
                        foreach(seen_node_id, e; undecided) {
                            callbacks.famous(e);
//                            callbacks.famous_mask(e);
                        }
                    }
                }
                else {
                    fout.writefln("Round %d NOT decided ", undecided.number);
                }
            }
        }
    }

    package void received_round(Round r)
        in {
            assert(r !is null, "Received round can not be null");
            assert(_received_round is null, "Received round has already been set");
        }
    do {
        _received_round=r;
    }

    const(Round) round() pure const nothrow
    out(result) {
        assert(result, "Round must be set before this function is called");
    }
    do {
        return _round;
    }

    Round round() pure nothrow
        in {
            if ( motherExists ) {
                assert(_mother, "Graph has not been resolved");
            }
        }
    do {
        if ( !_round ) {
            _round=_mother.round;
        }
        return _round;
    }

    // Round previous_round() pure nothrow
    //     in {
    //         assert(_round);
    //     }
    // do {
    //     return _round.previous;
    // }


    uint witness_votes(immutable uint node_size) {
        witness_mask(node_size);
        return _witness_votes;
    }

    uint witness_votes() pure const nothrow
        in {
            assert(is_witness_mask_checked);
        }
    do {
        return _witness_votes;
    }

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
                        auto mask=check_witness_mask(event.mother, level+1);
                        if ( mask.length < event._witness_mask.length ) {
                            mask.length = event._witness_mask.length;
                        }
                        else if ( mask.length > event._witness_mask.length ) {
                            event._witness_mask.length = mask.length;
                        }

                        event._witness_mask|=mask;

                    }
                    if ( event.father ) {
                        auto mask=check_witness_mask(event.father, level+1);
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

    ref const(BitArray) witness_mask() pure const nothrow
        in {
            assert(is_witness_mask_checked);
        }
    do {
        return _witness_mask;
    }

    // ref const(BitArray) round_mask() pure const nothrow
    //     in {
    //         assert(_witness);
    //     }
    // do {
    //     return _witness.seen_mask;
    // }


    const(Witness) witness() pure const nothrow {
        return _witness;
    }

    package Witness witness() {
        return _witness;
    }

    @trusted
    void strongly_seeing(Event previous_witness_event, ref const(BitArray) strong_seeing_mask)
        in {
            assert(!_strongly_seeing_checked);
            assert(_witness_mask.length != 0);
            assert(previous_witness_event);
        }
    do {
        bitarray_clear(_witness_mask, node_size);
        _witness_mask[node_id]=true;
        if ( _father && _father._witness !is null ) {
            // If father is a witness then the wintess is seen through this event
            _witness_mask|=_father.witness_mask;
        }
        _witness=new Witness(this, previous_witness_event, strong_seeing_mask);
        next_round;
        _witness.seeing_previous_round(this);
        if ( callbacks ) {
            callbacks.strongly_seeing(this);
        }
    }

    package void next_round() {
        // The round number is increased by one
        _round=Round(mother.round.number+1);
        // Event added to round
        _round.add(this);

    }

    bool strongly_seeing() const pure nothrow {
        return _witness !is null;
    }

    void strongly_seeing_checked()
        in {
            assert(!_strongly_seeing_checked);
        }
    do {
        _strongly_seeing_checked=true;
    }

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
            if ( mother.witness_mask[node_id] ) {
                result=true;
            }
            else if ( _round.lessOrEqual(mother._round) ) {
                result=mother._round.event(mother.node_id).seeing_witness(node_id);
            }
        }
        else if ( father ) {
            if ( father.witness_mask[node_id] ) {
                result=true;
            }
            else if ( _round.lessOrEqual(father._round) ) {
                result=father._round.event(father.node_id).seeing_witness(node_id);
            }
        }
        return result;
    }

    version(node)
    @trusted
    ref const(BitArray) seeing_witness_mask() const pure {
        if ( father ) {
            BitArray* result=new BitArray;
            *result=mother.witness_mask | father.witness_mask;
            return *result;
        }
        else {
            return mother.witness_mask;
        }
    }

    void forked(bool s)
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


    bool forked() const pure nothrow {
        return _forked;
    }


    immutable(int) altitude() const pure nothrow {
        return event_body.altitude;
    }

    immutable uint node_id;
// FixMe: CBR 19-may-2018
// Note pubkey is redundent information
// The node_id should be enought this will be changed later
    this(
        ref immutable(EventBody) ebody,
        RequestNet request_net,
        immutable(ubyte[]) signature,
        Pubkey pubkey,
        const uint node_id,
        const uint node_size) {
        event_body=ebody;
        this.node_id=node_id;
        this.id=next_id;
        _fingerprint=request_net.calcHash(event_body.serialize); //toCryptoHash(request_net);
        this.signature=signature;
        this.pubkey=cast(Buffer)pubkey;

        if ( isEva ) {
            // If the event is a Eva event the round is undefined
            BitArray strong_mask;
            bitarray_clear(strong_mask, node_size);
            _witness = new Witness(this, null, strong_mask);
            _round = Round.seed_round(node_size);

        }
    }

// Disconnect the Event from the graph
    @trusted
    void disconnect() {
        if ( _son ) {
            _son._grounded=true;
            _son._father=null;
        }
        if ( _daughter ) {
            _daughter._grounded=true;
            _daughter._mother=null;
        }
        _mother=_father=null;
        _daughter=_son=null;
        if ( _witness ) {
            _round.disconnect(this);
            _witness=null;
        }
        _round = null;
    }

    package void ground(H)(H h) {
        void grounding(Event e) @safe {
            if ( e ) {
                grounding(e._mother);
                h.eliminate(e.fingerprint);
                if ( callbacks ) {
                    callbacks.remove(e);
                }
                e.disconnect;
            }
        }
        grounding(this);
    }

    ~this() {
        disconnect();
    }

    Event mother(H)(H h, RequestNet request_net) {
        Event result;
        result=mother!true(h);
        if ( !result && motherExists ) {
            request_net.request(h, mother_hash);
            result=mother(h);
        }
        return result;
    }

    private Event mother(bool ignore_null_check=false, H)(H h)
        out(result) {
            static if ( !ignore_null_check) {
                if ( mother_hash ) {
                    assert(result, "the mother is not found");
                }
            }
        }
    do {
        if ( _mother is null ) {
            _mother = h.lookup(mother_hash);
        }
        return _mother;
    }

    inout(Event) mother() inout pure nothrow
    in {
        if ( mother_hash ) {
            assert(_mother);
            assert( (altitude-_mother.altitude) == 1 );
        }
        assert(!_grounded, "This event is grounded");
    }
    do {
        return _mother;
    }

    Event father(bool ignore_null_check=false, H)(H h)
        out(result) {
            static if ( !ignore_null_check) {
                if ( father_hash ) {
                    assert(result, "the father is not found");
                }
            }
            assert(!_grounded, "This event is grounded");
        }
    do {
        if ( _father is null ) {
            _father = h.lookup(father_hash);
        }
        return _father;
    }

    Event father(H)(H h, RequestNet request_net) {
        Event result;
        result=father!true(h);
        if ( !result && fatherExists ) {
            request_net.request(h, father_hash);
            result=father(h);
        }
        return result;
    }

    inout(Event) father() inout pure nothrow
    in {
        if ( father_hash ) {
            assert(_father);
        }
    }
    do {
        return _father;
    }

    inout(Event) daughter() inout pure nothrow {
        return _daughter;
    }

    void daughter(Event c)
        in {
            if ( _daughter !is null ) {
                assert( c !is null, "Daughter can not be set to null");
            }
        }
    do {
        if ( _daughter && (_daughter !is c) && !_forked ) {
            forked=true;
        }
        else {
            _daughter=c;
        }
    }

    inout(Event) son() inout pure nothrow {
        return _son;
    }

    void son(Event c)
        in {
            if ( _son !is null ) {
                assert( c !is null, "Son can not be set to null");
            }
        }
    do {
        if ( _son && (_son !is c) && !_forked ) {
            forked=true;
        }
        else {
            _son=c;
        }
    }

    void loaded()
        in {
            assert(!_loaded, "Event can only be loaded once");
        }
    do {
        _loaded=true;
    }

    bool is_loaded() const pure nothrow {
        return _loaded;
    }

    immutable(ubyte[]) father_hash() const pure nothrow {
        return event_body.father;
    }

    immutable(ubyte[]) mother_hash() const pure nothrow {
        return event_body.mother;
    }

    immutable(ubyte[]) payload() const pure nothrow {
        return event_body.payload;
    }

    ref immutable(EventBody) eventbody() const pure {
        return event_body;
    }

//True if Event contains a payload or is the initial Event of its creator
    bool containPayload() const pure nothrow {
        return payload.length != 0;
    }

    bool motherExists() const pure nothrow {
        return event_body.mother !is null;
    }

    bool fatherExists() const pure nothrow {
        return event_body.father !is null;
    }

// is true if the event does not have a mother or a father
    bool isEva() pure const nothrow
        in {
            assert(!_grounded, "This event is gounded");
        }
    do {
        return !motherExists;
    }

    immutable(Buffer) fingerprint() const pure nothrow
    in {
        assert(_fingerprint, "Hash has not been calculated");
    }
    do {
        return _fingerprint;
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

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// WireEvent

unittest { // Serialize and unserialize EventBody
    import tagion.crypto.SHA256;
    auto payload=cast(immutable(ubyte)[])"Some payload";
    auto mother=SHA256("self").digits;
    auto father=SHA256("other").digits;
//    auto creator=cast(immutable(ubyte)[])"creator";
    auto seed_body=EventBody(payload, mother, father, 0, 0);

    auto raw=seed_body.serialize;

    auto replicate_body=EventBody(raw);

    // Raw and repicate shoud be the same
    assert(seed_body == replicate_body);
//    auto seed_event=new Event(seed_body);
}
