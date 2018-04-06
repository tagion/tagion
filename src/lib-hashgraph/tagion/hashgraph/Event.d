module tagion.hashgraph.Event;

import std.datetime;   // Date, DateTime
import tagion.utils.BSON : Document;
//import tagion.crypto.Hash;
import tagion.hashgraph.GossipNet;
//import tagion.hashgraph.HashGraph : HashGraph;
import std.conv;
import std.bitmanip;

import std.stdio;
import std.format;

//alias R_BSON!true GBSON;

// import (
// 	"bytes"
// 	"crypto/ecdsa"
// 	"encoding/json"
// 	"fmt"
// 	"math/big"
// 	"time"

// 	"github.com/babbleio/babble/crypto"
// )
enum ConcensusFailCode {
    NON,
    NO_MOTHER,
    MOTHER_AND_FATHER_SAME_SIZE,
    MOTHER_AND_FATHER_CAN_NOT_BE_THE_SAME,
    PACKAGE_SIZE_OVERFLOW,
    EVENT_PACKAGE_MISSING_PUBLIC_KEY,
    EVENT_PACKAGE_MISSING_EVENT,
    EVENT_PACKAGE_BAD_SIGNATURE
}

@safe
class ConsensusException : Exception {
    immutable ConcensusFailCode code;
    this( immutable(char)[] msg, ConcensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
        this.code=code;
    }
}

@safe
class EventConsensusException : ConsensusException {
    this( immutable(char)[] msg, ConcensusFailCode code, string file = __FILE__, size_t line = __LINE__ ) {
//        writefln("msg=%s", msg);
        super( msg, code, file, line );
    }
}

@safe
void check(bool flag, ConcensusFailCode code, string msg, string file = __FILE__, size_t line = __LINE__) {
    if (!flag) {
        throw new EventConsensusException(msg, code, file, line);
    }
}

@safe
struct EventBody {
    immutable(ubyte)[] payload; // Transaction
    immutable(ubyte)[] mother; // Hash of the self-parent
    immutable(ubyte)[] father; // Hash of the other-parent

    ulong time;
    invariant {
        if ( (mother.length != 0) && (father.length != 0 ) ) {
            assert( mother.length == father.length );
        }
    }

    this(
        immutable(ubyte)[] payload,
        immutable(ubyte)[] mother,
        immutable(ubyte)[] father,
        immutable ulong time) inout {
        this.time      =    time;
        this.father    =    father;
        this.mother    =    mother;
        this.payload   =    payload;
        consensus();
    }

    this(immutable(ubyte)[] data) inout {
        auto doc=Document(data);
        this(doc);
    }

    @trusted
    this(Document doc, GossipNet gossipnet=null) inout {
        foreach(i, ref m; this.tupleof) {
            alias typeof(m) type;
            enum name=this.tupleof[i].stringof["this.".length..$];
            if ( doc.hasElement(name) ) {
                static if ( name == mother.stringof || name == father.stringof ) {
                    if ( gossipnet ) {
                        immutable event_id=doc[name].get!uint;
                        pragma(msg, "Name "~name~" type "~type.stringof);
                        this.tupleof[i]=gossipnet.eventHashFromId(event_id);
                    }
                    else {
                        this.tupleof[i]=doc[name].get!type;
                    }
                }
                else {
                    this.tupleof[i]=doc[name].get!type;
                }
            }
        }
        consensus();
    }

    void consensus() inout {
        if ( mother.length == 0 ) {
            // Seed event first event in the chain
//            writefln("father.length=%s index=%s", father.length, index);
            check(father.length == 0, ConcensusFailCode.NO_MOTHER, "If an event has no mother it can not have a father");
//            check(index == 0, "Because Eva does not have a mother the index of an Eva event must be zero");
        }
        else {
            if ( father.length != 0 ) {
                // If the Event has a father
                check(mother.length == father.length, ConcensusFailCode.MOTHER_AND_FATHER_SAME_SIZE, "Mother and Father must user the same hash function");
            }
//            writefln("Non Eva father.length=%s index=%s", father.length, index);
            //          check(index != 0, "This event is not an Eva event so the index mush be greater than zero");
            check(mother != father, ConcensusFailCode.MOTHER_AND_FATHER_CAN_NOT_BE_THE_SAME, "The mother and father can not be the same event");
        }
    }
//json encoding of body only
//    version(none)
    // @use_event_will used evnet-ids instead of hashs
    GBSON toBSON(const(Event) use_event=null) const {
        auto bson=new GBSON;
        foreach(i, m; this.tupleof) {
            enum name=this.tupleof[i].stringof["this.".length..$];
            static if ( __traits(compiles, m.toBSON) ) {
                bson[name]=m.toBSON;
            }
            else {
                bool flag=true;
                static if ( __traits(compiles, m !is null) ) {
                    flag=m !is null;
                }
                if (flag) {
                    if ( use_event && name == mother.stringof &&  use_event.mother ) {
                        bson[name]=use_event.mother.id;
                    }
                    else if ( use_event && name == father.stringof && use_event.father ) {
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
    immutable(ubyte)[] serialize(const(Event) use_event=null) const {
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
    void strongly_seeing(const(Event) e);
    void strong_vote(const(Event) e, immutable uint vote);
    void famous(const(Event) e);
    void round(const(Event) e);
    void forked(const(Event) e);
    void famous_votes(const(Event) e);
}

@safe
class Round {
    private Round _previous;
    // This indicates wish events belongs to this round
    private BitArray nodes_mask;
    // Counts the number of nodes in this round
    private uint _nodes;
    // Round number
    immutable int number;

    static int increase_number(const(Round) r) {
        if ( !r.isUndefined && r ) {
            if ( r.number == int.max ) {
                return 1;
            }
            else {
                return r.number+1;
            }
        }
        else {
            return 1;
        }
    }


    static uint countVotes(ref const(BitArray) mask) @trusted {
        uint votes;
        foreach(vote; mask) {
            if (vote) {
                votes++;
            }
        }
        return votes;
    }

    private static Round _undefined;
    static this() {
        _undefined=new Round();
    }

    private this() {
        number=-1;
        _previous=null;
    }

    @trusted
    this(Round r, immutable uint node_size) {
        _previous=r;
        number=increase_number(r);
        nodes_mask.length=node_size;
    }

    @trusted
    void setNode(immutable uint index)
        in {
            assert(!isUndefined);
        }
    body {
        if ( !nodes_mask[index] ) {
            _nodes++;
        }
        nodes_mask[index]=true;
    }

    @trusted
    bool containNode(immutable uint index) const
        in {
            assert(!isUndefined);
        }
    body {
        return nodes_mask[index];
    }

    uint nodes() const pure nothrow {
        return _nodes;
    }

    bool isUndefined() const nothrow {
        return this is _undefined;
    }

    static Round undefined() nothrow {
        return _undefined;
    }

    Round previous() {
        return _previous;
    }
}

@safe
class Event {
    alias Event delegate(immutable(ubyte[]) fingerprint, Event child) @safe Lookup;
    alias bool delegate(Event) @safe Assign;
//    alias immutable(Hash) function(immutable(ubyte)[] data) @safe FHash;
    static EventCallbacks callbacks;
    alias GossipNet.HashPointer HashPointer;
    alias GossipNet.Pubkey Pubkey;
    // Delegate function to load or find an Event in the event pool
//    static Lookup lookup;
    // Deleagte function to assign an Event to event pool
//    static Assign assign;
    // Hash function
//    static FHash fhash;
    // WireEvent wire_event;
    immutable(ubyte[]) signature;
    private immutable(EventBody)* _event_body;
//    private immutable(immutable(ubyte[])) event_body_data;
    private HashPointer _hash;
    // This is the internal pointer to the
    private Event _mother;
    private Event _father;
    private Event _daughter;
    private Event _son;

    // BigInt R, S;
    int topologicalIndex;

//    private bool _round_set;
    private Round  _round;
    // The withness mask contains the mask of the nodes
    // Which can be seen by the next rounds witness
    private BitArray* _witness_mask;
    private bool _witness;
    private bool _famous;
    private uint _famous_votes;
    private bool _strongly_seeing;
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

    void round(Round round)
        in {
            assert(round !is null, "Round must be defined");
            assert(_round is null, "Round is already set");
        }
    body {
//        this._round_set=true;
        this._round=round;
        if ( callbacks ) {
            callbacks.round(this);
        }
    }

    inout(Round) round() inout pure nothrow
    out(result) {
        assert(result, "Round should be defined before it is used");
    }
    body {
        return _round;
    }

    int round_number() pure const nothrow
        in {
            assert(_round !is null, "Round is not set for this Event");
        }
    body {
        return _round.number;
    }

    bool hasRound() const pure nothrow {
        return (_round !is null);
    }

    Round previousRound() // nothrow
        out(result) {
            assert(result, "Round must be set to none null");
        }
    body {
        Round search(Event event) {
            if (event) {
                if ( event.witness ) {
                    return event.round;
                }
                return search(event.mother);

            }
            return Round.undefined;
        }
        return search(mother);
    }

    version(none)
    Round motherRound() nothrow
    out(result) {
            assert(result, "Round must be set to none null");
        }
    body {
        if ( mother ) {
            return mother.round;
        }
        else {
            // Eva event get an undefined round
            return Round.undefined;
        }
    }

    void famous(bool f)
        in {
            if ( !f ) {
                assert(!_famous);
            }
        }
    body {
        if ( callbacks && !_famous && f) {
            _famous=true;
            callbacks.famous(this);
        }
        else {
            _famous=f;
        }
    }

    bool famous() pure const nothrow {
        return _famous;
    }

    private void increase_famous_votes() {
        _famous_votes++;
        if ( callbacks ) {
            callbacks.famous_votes(this);
        }
    }

    uint famous_votes() pure const nothrow {
        return _famous_votes;
    }

    void witness(immutable uint size)
        in {
            assert(!_witness);
        }
    body {
        _witness=true;
        if ( !_witness_mask ) {
            create_witness_mask(size);
        }
        if ( callbacks ) {
            callbacks.witness(this);
        }
    }

    bool witness() pure const nothrow {
    //     in {
    //         if ( _round || _witness_mask ) {
    //             writeln("False rounds");
    //         }
    //         assert(_round, "Round must ne defined for a witness");
    //         assert(_witness_mask, "Witness mask should be define for a witness");
    //     }
    // body
    // {
        return _witness;
    }

    @trusted
    private void create_witness_mask(immutable uint size)
        in {
            assert(_witness, "Witness mask can not be created for a none witness event");
            assert(_witness_mask is null, "Witness mask has already been created");
        }
    body {
        _witness_mask=new BitArray;
        _witness_mask.length=size;
    }

    @trusted
    void set_witness_mask(uint index)
        in {
            assert(_witness, "To set a witness mask the event must be a witness");
        }
    body {
        if (!(*_witness_mask)[index]) {
            (*_witness_mask)[index]=true;
            increase_famous_votes();
        }
    }

    ref const(BitArray) witness_mask() const pure nothrow
        in {
            assert(_witness, "Event is not a witness");
            assert(_witness_mask, "Witness mask should be set of a witness");
        }
    body {
        return *_witness_mask;
    }

    void strongly_seeing_checked()
        in {
            assert(!_strongly_seeing_checked);
        }
    body {
        _strongly_seeing_checked=true;
    }

    bool is_strogly_seeing_checked() const pure nothrow {
        return _strongly_seeing_checked;
    }

    void strongly_seeing(bool s)
        in {
            assert(!_strongly_seeing);
            assert(!_strongly_seeing_checked);
        }
    body {
        _strongly_seeing=s;
        if ( callbacks && s ) {
            callbacks.strongly_seeing(this);
        }
    }

    bool strongly_seeing() const pure nothrow {
        return _strongly_seeing;
    }

    void forked(bool s)
        in {
            if ( s ) {
                assert(!_forked, "An event can not unforked");
            }
        }
    body {
        _forked = s;
        if ( callbacks && _forked ) {
            callbacks.forked(this);
        }
    }


    bool forked() const pure nothrow {
        return _forked;
    }

    immutable uint node_id;
//    uint marker;
    @trusted
    this(ref immutable(EventBody) ebody, immutable(ubyte[]) signature,  GossipNet gossip_net, uint node_id=0) {
        _event_body=&ebody;
        this.node_id=node_id;
        this.id=next_id;
        this.signature=signature;
        //event_body_data = event_body.serialize;
//        if ( _hash ) {
        //_hash=fhash(event_body_data).digits;
        if ( isEva ) {
            // If the event is a Eva event the round is undefined
            _round = Round.undefined;
            _witness = true;
        }
//        }
//        if ( assign ) {
//        h.assign(this);
//        }
        // if ( callbacks ) {
        //     callbacks.create(this);
        // }
//        if ( fhash ) {
        _hash=toCryptoHash(gossip_net);
        assert(_hash);
//        }
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
    Event mother(H)(H h, GossipNet gossip_net) {
        Event result;
        result=mother!true(h);
        if ( !result && motherExists ) {
            gossip_net.request(h, mother_hash);
            result=mother(h);
        }
        return result;
    }

    Event mother(bool ignore_null_check=false, H)(H h)
        out(result) {
            static if ( !ignore_null_check) {
                if ( mother_hash ) {
                    assert(result, "the mother is not found");
                }
            }
        }
    body {
        if ( _mother is null ) {
            _mother = h.lookup(mother_hash);
        }
        return _mother;
    }

    inout(Event) mother() inout pure nothrow
    in {
        if ( mother_hash ) {
            //assert(_mother);
        }
    }
    body {
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
    body {
        if ( _father is null ) {
            _father = h.lookup(father_hash);
        }
        return _father;
    }

    Event father(H)(H h, GossipNet gossip_net) {
        Event result;
        result=father!true(h);
        if ( !result && fatherExists ) {
            gossip_net.request(h, father_hash);
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
    body {
        return _father;
    }

    inout(Event) daughter() inout pure nothrow {
        return _daughter;
    }

    void daughter(Event c)
        in {
            if ( _daughter !is null ) {
                assert( c !is null, "Daughter can not be set to null");
                // assert(_daughter is c,
                //     format(
                //         "Daughter pointer can not be change\n"~
                //         "mother           id=%d\n"~
                //         "current daughter id=%d\n"~
                //         "new daughter     id=%d",
                //         id, _daughter.id, c.id));
            }
        }
    body {
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
                // assert(_son is c,
                //     format(
                //         "Son pointer can not be change\n"~
                //         "father      id=%d\n"~
                //         "current son id=%d\n"~
                //         "new son     id=%d",
                //         id, _son.id, c.id));
            }
        }
    body {
        if ( _son && (_son !is c) && !_forked ) {
            forked=true;
        }
        else {
            _son=c;
        }
    }

    void loaded(bool c)
        in {
            assert(!_loaded, "Event can only be loaded once");
        }
    body {
        _loaded=c;
    }

    bool loaded() const pure nothrow {
        return _loaded;
    }

    immutable(ubyte[]) father_hash() const pure nothrow {
	return _event_body.father;
    }

    immutable(ubyte[]) mother_hash() const pure nothrow {
	return _event_body.mother;
    }

    immutable(ubyte[]) payload() const pure nothrow {
        return _event_body.payload;
    }

    ref immutable(EventBody) eventbody() const pure {
        return *_event_body;
    }
//True if Event contains a payload or is the initial Event of its creator
    bool containPayload() const pure nothrow {
	return payload.length != 0;
    }

    bool motherExists() const pure nothrow {
        return _event_body.mother !is null;
    }

    bool fatherExists() const pure nothrow {
        return _event_body.father !is null;
    }

    // is true if the event does not have a mother or a father
    bool isEva() const pure nothrow {
        return !motherExists && !fatherExists;
    }

// immutable(ubyte[]) toHash() {
    //     if ( !_hash ) {
    //         _hash = fhash(event_body.serialize);
    //     }
    //     return _hash;
    // }


    immutable(HashPointer) toCryptoHash() const pure nothrow
    in {
        assert(_hash, "Hash has not been calculated");
    }
    body {
        return _hash;
    }

//     @trusted
//     static immutable(HashPointer) cryptoHash(
//         GossipNet gossip_net,
// //        Pubkey pubkey,
//         ref immutable(EventBody) event_body ) {
//         auto bson=event_body.toBSON;
//         bson[pubkey.stringof]=pubkey;
//         return gossip_net.calcHash(bson.serialize);
//     }

    immutable(HashPointer) toCryptoHash(
        GossipNet gossip_net)
    in {
        if ( _hash ) {
            assert( _hash == gossip_net.calcHash(_event_body.serialize));
        }
    }
    body {
        if ( _hash ) {
            return _hash;
        }
        _hash=gossip_net.calcHash(_event_body.serialize);
        return _hash;
    }


    version(none)
    invariant {
        if ( (_mother) && (_mother._daughter) ) {
            if ( _mother._daughter !is this ) {
                writefln("Bad daughter=%d this=%d", _mother.daughter.id, id);
            }
            assert(_mother._daughter is this);

        }
        if ( (_father) && (_father._son) ) {
            if ( _father._son !is this ) {
                writefln("Bad son=%d this=%d", _father._son.id, id);
                writefln("\tfather=%s", _father._hash.toHexString);

                writefln("\tbad son=%s", _father._son._hash.toHexString);
                writefln("\t   this=%s", _hash.toHexString);
            }
            assert(_father._son is this);
        }
    }

    //Sorting

    // ByTimestamp implements sort.Interface for []Event based on
    // the timestamp field.
    struct ByTimestamp {
        Event[] a;

        uint Len() {
            return cast(uint)a.length;
        }
        void Swap(uint i, uint j)
            in {
                assert(i < a.length);
                assert(j < a.length);
                assert( i != j );
            }
        body {
            import mutation=std.algorithm.mutation;
            mutation.swap(a[i], a[j]);
        }

        bool Less(uint i, uint j)
            in {
                assert(i < a.length);
                assert(j < a.length);
                assert( i != j );
            }
        body {
            //normally, time.Sub uses monotonic time which only makes sense if it is
            //being called in the same process that made the time object.
            //that is why we strip out the monotonic time reading from the Timestamp at
            //the time of creating the Event
            return a[i]._event_body.time < a[j]._event_body.time;
        }
    }

// ByTopologicalOrder implements sort.Interface for []Event based on
// the topologicalIndex field.
    struct ByTopologicalOrder {
        Event[] a;

        uint Len() {
            return cast(uint)a.length;
        }
        void Swap(uint i, uint j)
            in {
                assert(i < a.length);
                assert(j < a.length);
                assert( i != j );
            }
        body {
            import mutation=std.algorithm.mutation;
            mutation.swap(a[i], a[j]);
        }
        bool Less(uint i, uint j) {
            return a[i].topologicalIndex < a[j].topologicalIndex;
        }
    }
}

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// WireEvent
//module tagion.hashgraph.EventEvent;

// import (
// 	"reflect"
// 	"testing"
// 	"time"

// 	"github.com/babbleio/babble/crypto"
// )

unittest { // Serialize and unserialize EventBody
    import tagion.crypto.SHA256;
    auto payload=cast(immutable(ubyte)[])"Some payload";
    auto mother=SHA256("self").digits;
    auto father=SHA256("other").digits;
    writeln("Serialize event");
//    auto creator=cast(immutable(ubyte)[])"creator";
    auto seed_body=EventBody(payload, mother, father, 0);

    auto raw=seed_body.serialize;

    auto replicate_body=EventBody(raw);

    // Raw and repicate shoud be the same
    assert(seed_body == replicate_body);
//    auto seed_event=new Event(seed_body);
}
