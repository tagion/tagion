module bakery.hashgraph.RoundInfo;

// import (
// 	"bytes"
// 	"encoding/json"
// 	"math/big"
// )

enum Trilean : int {
    Undefined=-1,
    False=0,
    True=1
};
// type Trilean int

// const (
// 	Undefined Trilean = iota
// 	True
// 	False
// )

// var trileans = []string{"Undefined", "True", "False"}

// func (t Trilean) String() string {
// 	return trileans[t]
// }

struct RoundEvent {
    bool Witness;
    Trilean Famous;
    this(bool witness) {
        Famous = Trilean.Undefined;
        Witness = witness;
    }
}

class RoundInfo(H) {
    RoundEvent[H] Events;
    bool queued;


// func NewRoundInfo() *RoundInfo {
// 	return &RoundInfo{
// 		Events: make(map[string]RoundEvent),
// 	}
// }

    void AddEvent(H x, bool witness) {
        if ( x !in Events ) {
            Events[x].Witness = witness;
	}
    }

    void SetFame(H x, bool f) {
        Event e;
        if ( x !in Events ) {
            e.Witness = true;
	}
        with(Trilean) {
            e.Famous = (f)?True:False;
        }
        Events[x].Famous = e;
    }

//return true if no witnesses' fame is left undefined
    bool WitnessesDecided() {
	foreach( ref e; Events ) {
            if ( e.Witness && ( e.Famous == Undefined ) ) {
                return false;
            }
	}
	return true;
    }

//return witnesses
    immutable(H[]) Witnesses() const {
        immutable(H)[] result;
	foreach(x, e;Events)  {
            if ( e.Witness ) {
                res~=x;
            }
	}
	return result;
    }

//return famous witnesses
    immutable(H[]) FamousWitnesses() const {
        immutable(H)[] result;
	foreach(x, e;Events)  {
            if ( e.Witness && ( e.Famous == True ) ) {
                result~=x;
            }
	}
	return result;
    }

    bool IsDecided(H witness) {
        auto w=(witness in Events);
        return w && w.Witness && (w.Famous != Undefined);
    }

    const(BigInt)* PseudoRandomNumber() {
        auto result=new BigInt;
        foreach( x, e; Events ) {
            if ( e.Witness &&  ( e.Famous == True ) ) {
                *result ^= x.to!BigInt;
            }
	}
	return result;
    }
}

/+
func (r *RoundInfo) Marshal() ([]byte, error) {
	var b bytes.Buffer
	enc := json.NewEncoder(&b)
	if err := enc.Encode(r); err != nil {
		return nil, err
	}
	return b.Bytes(), nil
}

func (r *RoundInfo) Unmarshal(data []byte) error {
	b := bytes.NewBuffer(data)
	dec := json.NewDecoder(b) //will read from b
	return dec.Decode(r)
}
+/
