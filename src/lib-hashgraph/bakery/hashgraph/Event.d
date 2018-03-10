module bakery.hashgraph.Event;

import std.datetime;   // Date, DateTime
import bakery.utils.BSON : R_BSON=BSON, Document;
import bakery.crypto.Hash;
import bakery.hashgraph.GossipNet;
//import bakery.hashgraph.HashGraph : HashGraph;
import std.conv;

import std.stdio;

alias R_BSON!true GBSON;

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
    immutable(ubyte)[] payload;
    immutable(ubyte)[] mother; // Hash of the self-parent
    immutable(ubyte)[] father; // Hash of the parent-parent

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
    this(Document doc) inout {
        foreach(i, ref m; this.tupleof) {
            alias typeof(m) type;
            enum name=this.tupleof[i].stringof["this.".length..$];
            if ( doc.hasElement(name) ) {
                this.tupleof[i]=doc[name].get!type;
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
    GBSON toBSON() const {
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
                    bson[name]=m;
                }
            }
        }
        return bson;
    }

    @trusted
    immutable(ubyte)[] serialize() const {
        return toBSON.expand;
    }

}

debug(RoundWarpTest) {
    alias byte Round;
}
else {
    alias int Round;
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
    void famous(const(Event) e);

}

@safe
class Event {
    alias Event delegate(immutable(ubyte[]) fingerprint, Event child) @safe Lookup;
    alias bool delegate(Event) @safe Assign;
    alias immutable(Hash) function(immutable(ubyte)[] data) @safe FHash;
    static EventCallbacks callbacks;
    // Delegate function to load or find an Event in the event pool
//    static Lookup lookup;
    // Deleagte function to assign an Event to event pool
//    static Assign assign;
    // Hash function
    static FHash fhash;
    // WireEvent wire_event;
    private immutable(EventBody)* event_body;
    private immutable(immutable(ubyte[])) event_body_data;
    private immutable(ubyte[]) _hash;
    // This is the internal pointer to the
    private Event _mother;
    private Event _father;

    // BigInt R, S;
    int topologicalIndex;

    private bool _round_set;
    private Round  _round;
    private bool _witness;
    private bool _famous;
    private bool _strongly_seeing;
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
            assert(!_round_set);
        }
    body {
        this._round_set=true;
        this._round=round;
    }

    Round round() pure const nothrow {
        return _round;
    }

    bool famous(bool f)
        in {
            assert(!_famous);
        }
    body {
        if ( callbacks && f ) {
            if ( !_witness ) {
                this.witness=true;
            }
            callbacks.famous(this);
        }
        return _famous=f;
    }

    bool famous() pure const nothrow {
        return _famous;
    }

    bool witness(bool w)
        in {
            assert(!_witness);
        }
    body {
        if ( callbacks && w ) {
            callbacks.witness(this);
        }
        return _witness=w;
    }

    bool witness() pure const nothrow {
        return _witness;
    }

    bool strongly_seeing(bool s)
        in {
            assert(!_strongly_seeing);
        }
    body {
        if ( callbacks && s ) {
            callbacks.strongly_seeing(this);
        }
        return _strongly_seeing;
    }


    immutable uint node_id;
    uint marker;
    @trusted
    this(ref immutable(EventBody) ebody, uint node_id=0) {
        event_body=&ebody;
        this.node_id=node_id;
        this.id=next_id;
        event_body_data = event_body.serialize;
//        if ( _hash ) {
        _hash=fhash(event_body_data).digits;
//        }
//        if ( assign ) {
//        h.assign(this);
//        }
        if ( callbacks ) {
            callbacks.create(this);
        }
//        if ( fhash ) {
        assert(_hash);
//        }
    }

    // Disconnect the Event from the graph
    void diconnect() {
        _mother=_father=null;
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
            _mother = h.lookup(mother_hash, this);
        }
        return _mother;
    }

    inout(Event) mother() inout pure nothrow
    in {
        if ( mother_hash ) {
            assert(_mother);
        }
    }
    out(result) {
        assert(result);
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
            _father = h.lookup(father_hash, this);
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
    out(result) {
        assert(result);
    }
    body {
        return _father;
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
// immutable(ubyte[]) toHash() {
    //     if ( !_hash ) {
    //         _hash = fhash(event_body.serialize);
    //     }
    //     return _hash;
    // }

    immutable(ubyte[]) toCryptoHash() const pure nothrow
    in {
        assert(_hash, "Hash has not been calculated");
    }
    body {
        return _hash;
    }

    immutable(ubyte[]) toData() const pure nothrow
    in {
        if ( event_body ) {
            assert(event_body_data, "Event body is not expanded");
        }
    }
    body {
        return event_body_data;
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
            return a[i].event_body.time < a[j].event_body.time;
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
//module bakery.hashgraph.EventEvent;

// import (
// 	"reflect"
// 	"testing"
// 	"time"

// 	"github.com/babbleio/babble/crypto"
// )

unittest { // Serialize and unserialize EventBody
    import bakery.crypto.SHA256;
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
