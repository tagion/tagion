module bakery.hashgraph.ConsensusSorter;

import std.bigint;
import bakery.hashgraph.Event;
struct ConsensusSorter(H) {
    Event!H[] a;
    RoundInfo[int] r;
    const(BigInt)*[int] cache;
    uint Len() const pure nothrow {
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

    bool Less(int i, int j) {
	int irr=-1;
        int jrr=-1;
	if ( a[i].roundReceived !is null ) {
            irr = a[i].roundReceived;
	}
	if ( a[j].roundReceived !is null ) {
            jrr = a[j].roundReceived;
	}
	if ( irr != jrr ) {
            return irr < jrr;
	}

	if ( !a[i].consensusTimestamp.Equal(a[j].consensusTimestamp) ) {
            return a[i].consensusTimestamp.Before(a[j].consensusTimestamp);
	}

        auto w = GetPseudoRandomNumber(a[i].roundReceived);
        auto wsi = new BigInt;
	auto wsi = a[i].S ^ w;
        auto wsj = new BigInt;
//	auto wsj = wsj.Xor(&b.a[j].S, w);
	auto wsj = a[j].S ^ w;
	return wsi < wsj;
    }


    this(Event[] events) {
        a=events;
    }

    const(BigInt)* GetPseudoRandomNumber(int round) const {
        auto ps=(round in cache);
        if ( ps is null ) {
            auto rd=r[round];
            ps = rd.PseudoRandomNumber();
            cache[round] = ps;
        }
        return ps;
    }
}
