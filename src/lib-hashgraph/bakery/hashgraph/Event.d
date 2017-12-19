module barkery.hashgraph.Event;

import (
	"bytes"
	"crypto/ecdsa"
	"encoding/json"
	"fmt"
	"math/big"
	"time"

	"github.com/babbleio/babble/crypto"
)

struct WireBody {
    immutable(ubyte)[] payload; //the payload
    //wire
    //It is cheaper to send ints then hashes over the wire
    int SelfParentIndex;
    int OtherParentCreatorID;
    int OtherParentIndex;
    int CreatorID;

    time.Time Timestamp ; //creator's claimed timestamp of the event's creation
    int Index;//index in the sequence of events created by Creator
}

class EventBody(H) {
    immutable(ubyte)[] payload;
    H[] Parents;  //hashes of the event's parents, self-parent first
    immutable(ubyte)[] Creator; //creator's public key
    // time.Time Timestamp;
    // int Index;
    // int selfParentIndex;
    // int otherParentCreatorID;
    // int otherParentIndex;
    // int creatorID;
    WireBody wirebody;

    enum recordnames {
        TIME,
        PAYLOAD,
        CREATOR,
        WIRES
    }

    this(
               Transactions: transactions,
          Parents:      parents,
          Creator:      creator,
          Timestamp:    time.Now().UTC(), //strip monotonic time
          Index:        index,

//json encoding of body only
    immutable(ubyte)[] Marshal() ([]byte, error) {
        auto bson=new GBSON;
        with (recordnames) {
            bson[TIME.stringof]=wirebody.Timestamp;
            bson[CREATOR.stringof]=wirebody.Creator;
            if ( payload ) {
                bson[PAYLOAD.stringof]=wirebody.payload;
            }
            const(int)[] wire=[
                wirebody.Index,
                wirebody.selfParantIndex,
                wirebody.otherParentCreatorID,
                wirebody.otherParentIndex,
                wirebody.creatorID
                ];
            bson[WIRES.stringof]=wires;
            return bson.expand;
        }
    }

    void Unmarshal(immutable(ubyte)[] data) {
        auto doc=Document(data);
        with (recordnames) {
            wirebody.Timestamp=doc[TIME.stringof].get!Time;
            if ( doc.has(PAYLOAD.stringof) ) {
                payload = doc[PAYLOAD.stringof].get!(immutable(ubyte)[]);
            }
            wirebody.Creator=doc[CREATOR.stringof].get!(immutable(ubyte)[]);
            auto wires=doc[WIRES.stringof].get(immutable(int)[]);
            uint i;
            wirebody.Index=wires[i++];
            wirebody.selfParantIndex=wires[i++];
            wirebody.otherParentCreatorID=wires[i++];
            wirebody.otherParentIndex=wires[i++];
            wirebody.creatorID=wires[i++];
        }
    }

    immutable(H) hash() {
        return H(Marshal);
    }
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
    WireEvent wire_event;
    // EventBody eventBody;
    // BigInt R, S;
    int topologicalIndex;

    int* roundReceived;
    time.Time consensusTimestamp;

    EventCoordinates[] lastAncestors;   //[participant fake id] => last ancestor
    EventCoordinates[] firstDescendants; //[participant fake id] => first descendant

    string creator;
    H hash;
    string hex;


    this(
        immutable(ubyte)[] payload,
	H[] parents;
	immutable(ubyte)[] creator
	int index) {


        event_body = EventBody {
          Transactions: transactions,
          Parents:      parents,
          Creator:      creator,
          Timestamp:    time.Now().UTC(), //strip monotonic time
          Index:        index,
	}
	return Event{
		Body: body,
	}
    }

    func (e *Event) Creator() string {
	if e.creator == "" {
		e.creator = fmt.Sprintf("0x%X", e.event_body.Creator)
            }
	return e.creator
            }


    Hash SelfParent() string {
	return e.event_body.Parents[0];
    }

    Hash OtherParent() {
	return event_body.Parents[1];
    }

    immutable(ubyte[][]) Transactions() {
        return e.event_body.Transactions;
    }

    int Index() int {
	return e.event_body.Index;
    }

//True if Event contains a payload or is the initial Event of its creator
    bool IsLoaded() bool {
	if ( e.event_body.Index == 0 ) {
            return true;
	}
	return e.event_body.Transactions.length != 0;
    }

//ecdsa sig
    error Sign(ecdsa.PrivateKey privKey) error {
	signBytes, err := e.event_body.Hash();
	if ( err !is nil ) {
            return err;
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

//json encoding of body and signature
func (e *Event) Marshal() ([]byte, error) {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	if err := enc.Encode(e); err != nil {
        return nil, err;
	}
	return b.Bytes(), nil
            }

func (e *Event) Unmarshal(data []byte) error {
	b := bytes.NewBuffer(data)
	dec := json.NewDecoder(b) //will read from b
	return dec.Decode(e)
}

//sha256 hash of body and signature
    immutable(ubyte)[] Hash() ([]byte, error) {
        if ( e.hash.length == 0 ) {
            hashBytes, err := e.Marshal()
                if ( err !is null )  {
                    return nil, err
                }
            e.hash = crypto.SHA256(hashBytes);
        }
        return e.hash;
    }

    func (e *Event) string Hex() {
        if ( e.hex == "" ) {
            hash, _ := e.Hash();
            e.hex = fmt.Sprintf("0x%X", hash);
        }
        return e.hex;
    }

    void SetRoundReceived(int rr) {
        if ( roundReceived is null ) {
            roundReceived = new(int);
	}
	*roundReceived = rr;
    }

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


//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// WireEvent
