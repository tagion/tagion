module barkery.hashgraph.Event;

import std.datetime;   // Date, DateTime
import bakery.utils.BSON : R_BSON=BSON, Document;
import std.conv;

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

version(none)
struct WireBody {
    immutable(ubyte)[] payload; //the payload
    //wire
    //It is cheaper to send ints then hashes over the wire
    int SelfParentIndex;
    int OtherParentCreatorID;
    int OtherParentIndex;
    int CreatorID;

    DateTime Timestamp ; //creator's claimed timestamp of the event's creation
    int Index;//index in the sequence of events created by Creator
}

struct EventBody {
    immutable(ubyte[]) payload;
    immutable(ubyte[]) mother;  // Hash of the self-parent
    immutable(ubyte[]) father; // Hash of the event-parent

    immutable(ubyte[]) creator; //creator's public key
    immutable DateTime timeStamp;
    immutable uint index;

    // int Index;
    // int selfParentIndex;
    // int otherParentCreatorID;
    // int otherParentIndex;
    // int creatorID;
//    WireBody wirebody;

    enum Recordnames {
        TIME,
        PAYLOAD,
        MOTHER,
        FATHER,
        CREATOR,
        INDEX
    }

    this(
        immutable(ubyte)[] payload,
        immutable(ubyte)[] mother,
        immutable(ubyte)[] father,
        immutable(ubyte)[] creator,
        immutable uint index) {
        //this.time      =    time.Now().UTC(); //strip monotonic time
        this.index     =    index;
        //this.index     =    index;
        this.father    =    father;
        this.mother    =    mother;
        this.creator   =    creator;
    }

    this(immutable(ubyte)[] data) {
        auto doc=Document(data);
        import std.string;
        foreach(i, m; this.tupleof) {
            alias typeof(m) type;
            enum name=EventBody.tupleof[i].stringof;
            auto test=this.tupleof[i];
            auto test2=doc[name];
//            auto test2=doc[name].get!type;
            //     this.tupleof[i]=doc(name).get!type;
        }
    }

//json encoding of body only
    version(none)
    immutable(ubyte)[] stearmout() const {
        auto bson=new GBSON;
        foreach(rec; Recordnames.min..Recordnames.max) {
            immutable name=to!string(rec);
            with(Recordnames) final switch(rec) {
                case TIME:
                    bson[name]=time;
                    break;
                case PAYLOAD:
                    bson[name]=payload;
                    break;
                case MOTHER:
                    bson[name]=mother;
                    break;
                case FATHER:
                    bson[name]=father;
                    break;
                case CREATOR:
                    bson[name]=creator;
                    break;
                case INDEX:
                    bson[name]=index;
                    break;
                }
        }
        return bson.expand;
    }

    /+
    version(none)
    static ref EventBody streamin(immutable(ubyte)[] data) {
        auto doc=Document(data);
        import std.string;
        string expand(Recordnames rec)() {
            static if ( rec < Recordnames.max ) {
                enum name=toLower(to!string(rec));
                return name~" : doc(\""~name~"\"), "~expand!(cast(Recordnames)(rec+1))();
            }
            return "";
        }
        enum expand_stream=
            "EventBody result={"~
            expand!(Recordnames.min)()~
            "};";

        pragma(msg, expand_stream);
        with(Recordnames) {
            mixin(expand_stream);
        }
        return result;
    }
    +/
        // foreach(rec; Recordnames.min..Recordnames.max) {
        //     immutable name=to!string(rec);
        //     with(Recordnames) final switch(rec) {
        //         case TIME:
        //             time=doc[name].get!Time;
        //             break;
        //         case PAYLOAD:
        //             payload=doc[name].get!(immutable(ubyte)[]);
        //             break;
        //         case MOTHER:
        //             mother=doc[name].get!(immutable(ubyte)[]);
        //             break;
        //         case FATHER:
        //             father=doc[name].get!(immutable(ubyte)[]);
        //             break;
        //         case CREATOR:
        //             creator=doc[name].get!(immutable(ubyte)[]);
        //             break;
        //         case INDEX:
        //             bson[name]=doc[name].get!(uint);
        //             break;
        //         }
        // }
        //}


    invariant {
        assert(mother.length == 0);
        assert(mother.length == father.length);

    }
    // immutable(H) hash() {
    //     return H(Marshal);
    // }
}

/+ ++++/

class Event(H) {
    struct EventCoordinates(H) {
        H hash;
        int index;
    }

    struct WireEvent {
        WireBody wire_body;
        BigInt R, S; //creator's digital signature of body
    }
//    WireEvent wire_event;
    // EventBody eventBody;
    // BigInt R, S;
    int topologicalIndex;

    int* roundReceived;
    time.Time consensusTimestamp;

    EventCoordinates[] lastAncestors;   //[participant fake id] => last ancestor
    EventCoordinates[] firstDescendants; //[participant fake id] => first descendant

    immutable(ubyte)[] creator; // Public key
    H[2] parents;
    string hex;
    enum recordnames {
        PARENTS,
        TIME,
        CREATOR,
        WIRES
    }


    this(
        ref const(Event!H) event_father,
        ref const(Event!H) event_mother,
        immutable(ubyte)[] payload ) {
        event_body = new EventBody(
            payload,
            parents,
            creator,
            index);
    }

    /+
    func (e *Event) Creator() string {
	if e.creator == "" {
		e.creator = fmt.Sprintf("0x%X", e.event_body.Creator)
            }
	return e.creator
            }
            +/

    immutable(H) SelfParent() const pure nothrow {
	return event_body.Parents[0];
    }

    immutable(H) OtherParent() const pure nothrow {
	return event_body.Parents[1];
    }

    immutable(ubyte[]) Transactions() const pure nothrow {
        return event_body.Transactions;
    }

    int Index() const {
	return event_body.Index;
    }

//True if Event contains a payload or is the initial Event of its creator
    bool IsLoaded() const {
	if ( event_body.Index == 0 ) {
            return true;
	}
	return event_body.Transactions.length != 0;
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
    void SetRoundReceived(int rr) {
        if ( roundReceived is null ) {
            roundReceived = new int;
	}
	*roundReceived = rr;
    }

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
        Eveny[] a;

        uint Len() {
            return a.length;
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
            return a[i].Body.Timestamp.Before(a[j].Body.Timestamp);
        }
    }

// ByTopologicalOrder implements sort.Interface for []Event based on
// the topologicalIndex field.
    struct ByTopologicalOrder {
        Event[] a;

        uint Len() {
            return a.length;
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
