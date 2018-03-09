module bakery.hashgraph.Event;

import std.datetime;   // Date, DateTime
import bakery.utils.BSON : R_BSON=BSON, Document;
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

void check(bool flag, ConcensusFailCode code, string msg, string file = __FILE__, size_t line = __LINE__) {
    if (!flag) {
        throw new EventConsensusException(msg, code, file, line);
    }
}

struct EventBody {
    immutable(ubyte)[] payload;
    immutable(ubyte)[] mother;  // Hash of the self-parent
    immutable(ubyte)[] father; // Hash of the event-parent

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
    alias Event delegate(immutable(ubyte)[] fingerprint, Event child) @safe Lookup;
    alias bool delegate(Event) @safe Assign;
    static EventCallbacks callbacks;
    // Delegate function to load or find an Event in the event pool
    static Lookup lookup;
    // Deleagte function to assign an Event to event pool
    static Assign assign;
    // struct EventCoordinates(H) {
    //     H hash;
    //     int index;
    // }

    // struct WireEvent {
    //     WireBody wire_body;
    //     BigInt R, S; //creator's digital signature of body
    // }
//    WireEvent wire_event;
    private immutable(EventBody)* event_body;
    // This is the internal pointer to the
    private Event _mother;
    private Event _father;
    private Event _child;

    // BigInt R, S;
    int topologicalIndex;

    private bool _round_set;
    private Round  _round;
    private bool _witness;
    private bool _famous;
    private bool _strongly_seeing;
    private immutable uint id;
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

//    time.Time consensusTimestamp;

    // EventCoordinates[] lastAncestors;   //[participant fake id] => last ancestor
    // EventCoordinates[] firstDescendants; //[participant fake id] => first descendant

    // immutable(ubyte)[] creator; // Public key
    // H[2] parents;
    // string hex;
    // enum recordnames {
    //     PARENTS,
    //     TIME,
    //     CREATOR,
    //     WIRES
    // }

    immutable uint node_id;
    uint marker;
    @trusted
    this(ref immutable(EventBody) ebody, uint node_id=0) {
        event_body=&ebody;
        this.node_id=node_id;
        this.id=next_id;
        if ( assign ) {
            assign(this);
        }
        writefln("Create Event");
        if ( callbacks ) {
            callbacks.create(this);
        }

    }

    // Disconnect the Event from the graph
    void diconnect() {
        if ( _child ) {
            if ( child._mother is this ) {
                child._mother = null;
            }
            else if ( child._father is this ) {
                child._father = null;
            }
            else {
                throw new HashGraphException("Child does not have a parent");
            }
        }
        _child=_mother=_father=null;
    }

    Event child() {
        return _child;
    }

    Event mother() {
        if ( _mother is null ) {
            _mother = lookup(mother_hash, this);
        }
        return _mother;
    }

    const(Event) mother() const pure
        in {
            if ( mother_hash ) {
                assert(_mother);
            }
        }
    body {
        return _mother;
    }

    Event father() {
        if ( _father is null ) {
            _father = lookup(father_hash, this);
        }
        return _father;
    }

    const(Event) father() const pure
        in {
            if ( father_hash ) {
                assert(_father);
            }
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
    bool containPayload() const {
	return payload.length != 0;
    }

//ecdsa sig
    /+
    bool Sign(ecdsa.PrivateKey privKey) {
	signBytes := event_body.Hash();
	if ( signBytes.length == 0 ) {
            return true;
	}
	R, S, err := crypto.Sign(privKey, signBytes);
        if ( err !is nil ) {
            return err;
        }
	e.R, e.S = *R, *S;
        return err;
    }

    bool Verify()  {
        pubBytes = e.event_body.Creator;
        pubKey = crypto.ToECDSAPub(pubBytes);

	signBytes = e.event_body.Hash();

	return crypto.Verify(pubKey, signBytes, &e.R, &e.S);
    };
    +/

//json encoding of body and signature
/++
    immutable(ubyte)[] Marshal() {
        auto bson=new BSON;
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	if err := enc.Encode(e); err != nil {
            return nil;
	}
	return b.Bytes();
    }



    const(Event) Unmarshal(data []byte) {
        auto b = bytes.NewBuffer(data);
        auto dec = json.NewDecoder(b); //will read from b
        return dec.Decode(e);
    }
+/

//sha256 hash of body and signature
    /+
    immutable(ubyte)[] Hash() {
        if ( e.hash.length == 0 ) {
            hashBytes, err := e.Marshal()
                if ( err !is null )  {
                    return nil, err
                }
            e.hash = crypto.SHA256(hashBytes);
        }
        return e.hash;
    }

    string Hex() const {
        if ( e.hex == "" ) {
            hash, _ := e.Hash();
            e.hex = fmt.Sprintf("0x%X", hash);
        }
        return e.hex;
    }
+/
    // void SetRoundReceived(int rr) {
    //     if ( roundReceived is null ) {
    //         roundReceived = new int;
    //     }
    //     *roundReceived = rr;
    // }

    /+
    void  SetWireInfo(int selfParentIndex,
        int otherParentCreatorID,
        int otherParentIndex,
        int creatorID int) {
        with (event_body.wire_body) {
            selfParentIndex = selfParentIndex;
            otherParentCreatorID = otherParentCreatorID;
            otherParentIndex = otherParentIndex;
            creatorID = creatorID;
        }
    }
+/
    version(none)
    const(WireEvent) ToWire() const {
        return wire_event;
	// return WireEvent{
        //   Body: WireBody{
        //       Transactions:         e.Body.Transactions,
        //             SelfParentIndex:      e.Body.selfParentIndex,
        //             OtherParentCreatorID: e.Body.otherParentCreatorID,
        //             OtherParentIndex:     e.Body.otherParentIndex,
        //             CreatorID:            e.Body.creatorID,
        //             Timestamp:            e.Body.Timestamp,
        //             Index:                e.Body.Index,
        //             },
	// 	R: e.R,
	// 	S: e.S,
        //         };
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

/++
    EventBody createDummyEventBody() EventBody {
	body := EventBody{}
	body.Transactions = [][]byte{[]byte("abc"), []byte("def")}
	body.Parents = []string{"self", "other"}
	body.Creator = []byte("public key")
	body.Timestamp = time.Now().UTC()
	return body
                 }

func TestMarshallBody(t *testing.T) {
	body := createDummyEventBody()

	raw, err := body.Marshal()
	if err != nil {
		t.Fatalf("Error marshalling EventBody: %s", err)
	}

	newBody := new(EventBody)
	if err := newBody.Unmarshal(raw); err != nil {
		t.Fatalf("Error unmarshalling EventBody: %s", err)
	}

	if !reflect.DeepEqual(body.Transactions, newBody.Transactions) {
		t.Fatalf("Payloads do not match. Expected %#v, got %#v", body.Transactions, newBody.Transactions)
	}
	if !reflect.DeepEqual(body.Parents, newBody.Parents) {
		t.Fatalf("Parents do not match. Expected %#v, got %#v", body.Parents, newBody.Parents)
	}
	if !reflect.DeepEqual(body.Creator, newBody.Creator) {
		t.Fatalf("Creators do not match. Expected %#v, got %#v", body.Creator, newBody.Creator)
	}
	if body.Timestamp != newBody.Timestamp {
		t.Fatalf("Timestamps do not match. Expected %#v, got %#v", body.Timestamp, newBody.Timestamp)
	}

}
+/
/+
func TestSignEvent(t *testing.T) {
	privateKey, _ := crypto.GenerateECDSAKey()
	publicKeyBytes := crypto.FromECDSAPub(&privateKey.PublicKey)

	body := createDummyEventBody()
	body.Creator = publicKeyBytes

	event := Event{Body: body}
	if err := event.Sign(privateKey); err != nil {
		t.Fatalf("Error signing Event: %s", err)
	}

	res, err := event.Verify()
	if err != nil {
		t.Fatalf("Error verifying signature: %s", err)
	}
	if !res {
		t.Fatalf("Verify returned false")
	}
}


func TestMarshallEvent(t *testing.T) {
	privateKey, _ := crypto.GenerateECDSAKey()
	publicKeyBytes := crypto.FromECDSAPub(&privateKey.PublicKey)

	body := createDummyEventBody()
	body.Creator = publicKeyBytes

	event := Event{Body: body}
	if err := event.Sign(privateKey); err != nil {
		t.Fatalf("Error signing Event: %s", err)
	}

	raw, err := event.Marshal()
	if err != nil {
		t.Fatalf("Error marshalling Event: %s", err)
	}

	newEvent := new(Event)
	if err := newEvent.Unmarshal(raw); err != nil {
		t.Fatalf("Error unmarshalling Event: %s", err)
	}

	if !reflect.DeepEqual(*newEvent, event) {
		t.Fatalf("Events are not deeply equal")
	}
}

func TestWireEvent(t *testing.T) {
	privateKey, _ := crypto.GenerateECDSAKey()
	publicKeyBytes := crypto.FromECDSAPub(&privateKey.PublicKey)

	body := createDummyEventBody()
	body.Creator = publicKeyBytes

	event := Event{Body: body}
	if err := event.Sign(privateKey); err != nil {
		t.Fatalf("Error signing Event: %s", err)
	}

	event.SetWireInfo(1, 66, 2, 67)

	expectedWireEvent := WireEvent{
		Body: WireBody{
			Transactions:         event.Body.Transactions,
			SelfParentIndex:      1,
			OtherParentCreatorID: 66,
			OtherParentIndex:     2,
			CreatorID:            67,
			Timestamp:            event.Body.Timestamp,
			Index:                event.Body.Index,
		},
		R: event.R,
		S: event.S,
	}

	wireEvent := event.ToWire()

	if !reflect.DeepEqual(expectedWireEvent, wireEvent) {
		t.Fatalf("WireEvent should be %#v, not %#v", expectedWireEvent, wireEvent)
	}
}

func TestIsLoaded(t *testing.T) {
	//nil payload
	event := NewEvent(nil, []string{"p1", "p2"}, []byte("creator"), 1)
	if event.IsLoaded() {
		t.Fatalf("IsLoaded() should return false for nil Body.Transactions")
	}

	//empty payload
	event.Body.Transactions = [][]byte{}
	if event.IsLoaded() {
		t.Fatalf("IsLoaded() should return false for empty Body.Transactions")
	}

	//initial event
	event.Body.Index = 0
	if !event.IsLoaded() {
		t.Fatalf("IsLoaded() should return true for initial event")
	}

	//non-empty payload
	event.Body.Transactions = [][]byte{[]byte("abc")}
	if !event.IsLoaded() {
		t.Fatalf("IsLoaded() should return true for non-empty payload")
	}
}
+/
