module tagion.hashgraph.Event;

import std.datetime;   // Date, DateTime
import tagion.utils.BSON : HBSON, Document;

import tagion.crypto.Hash;

import tagion.hashgraph.GossipNet;
import tagion.hashgraph.ConsensusExceptions;
//import tagion.hashgraph.HashGraph : HashGraph;
import std.conv;
import std.bitmanip;

//import std.stdio;
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
    //alias HashPointer=RequestNet.HashPointer;
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

//    @trusted
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
//                    pragma(msg, "EventBody " ~ name ~ " type=" ~is(type : immutable(ubyte[])).to!string);
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
//json encoding of body only
//    version(none)
    // @use_event_will used evnet-ids instead of hashs
    HBSON toBSON(const(Event) use_event=null) const {
        auto bson=new HBSON;
        foreach(i, m; this.tupleof) {
            enum name=basename!(this.tupleof[i]);
//            fout.writefln("EventBody %s", name);
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


/+ ++++/
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
    void famous(const(Event) e);
    void round(const(Event) e);
    void forked(const(Event) e);
    void famous_votes(const(Event) e);
    void iterations(const(Event) e, const uint count);
}

@safe
class Round {
    private Round _previous;
    // // This indicates wish events belongs to this round
    // private BitArray nodes_mask;
    // Counts the number of nodes in this round
    private uint _nodes;
    // Round number
    immutable int number;

    static int increase_number(const(Round) r) {
        return r.number+1;
        // if ( !r.isUndefined && r ) {
        //     return r.number+1;
        // }
        // else {
        //     return 1;
        // }
    }


    private static Round _undefined;
    static this() {
        _undefined=new Round();
    }

    private this() {
        number=-1;
        _previous=null;
    }

    bool lessOrEqual(const Round rhs) pure const {
        return (number - rhs.number) <= 0;
    }

//    @trusted
    this(Round r) { //, immutable uint node_size) {
        _previous=r;
        number=increase_number(r);
//        nodes_mask.length=node_size;
    }

    Round next() {
        //     immutable uint size=cast(uint)(nodes_mask.length);
        return new Round(this);
    }

    // @trusted
    // bool containNode(immutable uint index) const
    //     in {
    //         assert(!isUndefined);
    //     }
    // do {
    //     return nodes_mask[index];
    // }

    uint nodes() const pure nothrow {
        return _nodes;
    }

    bool isUndefined() const nothrow {
        return this is _undefined;
    }

    static Round undefined() nothrow {
        return _undefined;
    }

    Round previous() pure nothrow {
        return _previous;
    }
}

@safe
class Witness {
    private Event _previous_witness_event;
    private BitArray _famous_mask;
    private uint     _famous_votes;
    private uint     _famous_count;
    @trusted
    this(Event previous_witness_event, const uint nodes) {
        _famous_mask.length=nodes;
        _previous_witness_event=previous_witness_event;
    }
    const(Event) event() pure const nothrow {
        return _previous_witness_event;
    }

    @trusted
    void vote_famous(Event e, immutable uint node_id, const(bool) famous) {
        if ( _famous_mask[node_id] ) {
            if ( famous ) {
                _famous_votes++;
            }
            _famous_count++;
            _famous_mask[node_id]=true;
            // if ( famous_decided ) {
            //     e.round.famous[
            // }
        }
    }

    bool famous_decided() pure const nothrow {
        immutable node_size=cast(uint)_famous_mask.length;
        return node_size == _famous_count;
    }

    uint famous_votes() pure const nothrow {
        return _famous_votes;
    }

    bool famous() pure const nothrow {
        immutable node_size=cast(uint)_famous_mask.length;
        return isMajority(_famous_votes, node_size);
    }

    ref const(BitArray) famous_mask() pure const nothrow {
        return _famous_mask;
    }
}

@safe
class Event {
    alias Event delegate(immutable(ubyte[]) fingerprint, Event child) @safe Lookup;
    alias bool delegate(Event) @safe Assign;
//    alias immutable(Hash) function(immutable(ubyte)[] data) @safe FHash;
    static EventCallbacks callbacks;
//    alias GossipNet.HashPointer HashPointer;
    //alias GossipNet.Pubkey Pubkey;
    // Delegate function to load or find an Event in the event pool
    // Delegate function to assign an Event to event pool
    immutable(ubyte[]) signature;
    immutable(Buffer) pubkey;
    Pubkey channel() pure const nothrow {
        return cast(Pubkey)pubkey;
    }
    // The altitude increases by one from mother to daughter
    immutable(EventBody) event_body;

    private Buffer _fingerprint;
    // This is the internal pointer to the
    private Event _mother;
    private Event _father;
    private Event _daughter;
    private Event _son;


    //    private bool _round_set;
    private Round  _round;
    private Round  _recieved_round;

    // The withness mask contains the mask of the nodes
    // Which can be seen by the next rounds witness

    private Witness _witness;
    private uint _witness_votes;
    private BitArray _witness_mask;

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


    // void round(Round round)
    //     in {
    //         assert(round !is null, "Round must be defined");
    //         assert(_round is null, "Round is already set");
    //     }
    // do {
    //     this._round=round;
    //     if ( callbacks ) {
    //         callbacks.round(this);
    //     }
    // }

    inout(Round) round() inout pure // nothrow
    out(result) {
        assert(result, "Round should be defined before it is used");
    }
    do {
        return _round;
    }

    int round_number() pure const nothrow
        in {
            assert(_round !is null, "Round is not set for this Event");
        }
    do {
        return _round.number;
    }

    bool hasRound() const pure nothrow {
        return (_round !is null);
    }


    void recieved_round(Round r)
        in {
            assert(r !is null, "Received round can not be null");
            assert(_recieved_round is null, "Received round has already been set");
        }
    do {
        _recieved_round=r;
    }

    int received_round_number() pure const nothrow
        in {
            assert(_recieved_round !is null);
        }
    do {
        return _recieved_round.number;
    }

    uint famous_votes() pure const nothrow
        in {
            assert(_witness);
        }
    do {
        return _witness.famous_votes;
    }

    ref const(BitArray) famous_mask() pure const nothrow
        in {
            assert(_witness);
        }
    do {
        return _witness.famous_mask;
    }

    bool famous() pure const nothrow
        in {
            assert(_witness);
        }
    do {
        return _witness.famous;
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

    Round previousRound() pure nothrow
        in {
            assert(_round);
        }
    do {
        return _round.previous;
    }


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
        // import std.stdio;
        // immutable node_size=cast(uint)(_witness2_mask.length);
        // BitArray zero;
        // writefln("node_size=%d", node_size);
        // set_bitarray(zero, node_size);
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
                        // writefln("\t** dauhter=%s:%d mask=%s:%d", _witness2_mask, _witness2_mask.length, mask, mask.length);
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
                        //writefln("\t** son    =%s mask=%s", _witness2_mask, mask);
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


    const(Witness) witness() pure const nothrow {
        return _witness;
    }

    package Witness witness() {
        return _witness;
    }

    @trusted
    void strongly_seeing(Event previous_witness_event)
        in {
            assert(!_strongly_seeing_checked);
            assert(_witness_mask.length != 0);
            assert(previous_witness_event);
            //       assert(previous_witness_event._witness);
        }
    do {
        immutable node_size=cast(uint)(_witness_mask.length);
        bitarray_clear(_witness_mask, node_size);
        _witness_mask[node_id]=true;
        if ( _father && _father._witness !is null ) {
            // If father is a witness then the wintess is seen through this event
            _witness_mask|=_father.witness_mask;
        }
        _witness=new Witness(previous_witness_event, node_size);
        _round=mother.round.next;
        if ( callbacks ) {
            callbacks.strongly_seeing(this);
        }
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
        uint node_id) {
        event_body=ebody;
        this.node_id=node_id;
        this.id=next_id;
        _fingerprint=request_net.calcHash(event_body.serialize); //toCryptoHash(request_net);
        this.signature=signature;
        this.pubkey=cast(Buffer)pubkey;

        if ( isEva ) {
            // If the event is a Eva event the round is undefined
            _witness = new Witness(null, 0);
            _round = Round.undefined;

        }
    }

// Disconnect the Event from the graph
    void diconnect() {
        _mother=_father=null;
        _daughter=_son=null;
        _round = null;
    }

    ~this() {
        diconnect();
    }

    Event mother(H)(H h, RequestNet request_net) {
        Event result;
        result=mother!true(h);
        if ( !result && motherExists ) {
            request_net.request(h, mother_hash);
            result=mother(h);
//            _round2=result._round2;
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

    inout(Event) mother() inout pure // nothrow
    in {
        if ( mother_hash ) {
            debug {
                import std.stdio;
                if ( _mother is null ) {
                    writefln("Mother is null");
                }
            }

            assert(_mother);
            assert( (altitude-_mother.altitude) == 1 );
        }
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
    bool isEva() pure const nothrow {
        return !motherExists;
    }
// bool isEva() const nothrow
//     out (result) {
//         if (result) {
//             assert(father_hash is null);
//             if ( _round2 ) {
//                 assert(_round2.isUndefined );
//             }
//         }
//     }
// do {
//     return mother_hash is null;
// }

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
