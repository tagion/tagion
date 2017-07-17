/**
   This takes care to the transport layer to other Baking Sheets (node)
   In the Bitcuits network
 */

module Bakery.Owen.BitcuitBlock;

/**

 */
@safe
struct LedgerItem(H) {
    /**
       Ledger header format.
       struct {
          uint size; // Size in bytes
          Time time;
          int count;
          ..
          ..

     */
    enum {
        size_end = uint.sizeof;
        time_end = size_end + Time.sizeof;
        count_end = time_end.sizeof + int.sizeof;
    };
    this(const(byte)[] ledger)
    in {
        assert(lendger.sizeof > count_end,
            "Ledger violation. Size of the ledger block too small"
            );
        assert(cast(immutable(uint))ledger[0..size_end] == cast(immutable(uint))ledger[size_end..$].length,
            "Ledger record length is false"
            );
    }
    body {
        this.ledger = ledger.idup;
    }
    immutable(uint) size() const pure nothrow {
        return cast(immutable(uint))ledger[0..size_end];
    }
    immutable(Time) time() const pure nothrow {
        return cast(immutable(Time))ledger[size_end..time_end];
    }
    immutable(uint) count() const pure nothrow {
        return cast(immutable(Time))ledger[size_time..count_end];
    }
    immutable(byte)[] data() const pure nothrow {
        return ledger;
    }

    int opComp(const(LedgerItem(H)) a, const(LedgerItem(H)) b) const pure nothrow {
        if ( a == b ) {
            return 0;
        }
        else if ( a.time < b.time ) {
            return -1;
        }
        else if ( a.time > b.time ) {
            return 1;
        }
        else {
            auto aHash = H(a);
            auto bHash = H(b);
            if ( aHash < bHash ) {
                return -1;
            }
            else if ( aHash > bHash ) {
                return 1;
            }
            assert(0, "What!!! this is not possible we have a hash problem or somebody have hacked the world");
        }
    }
private:
    immutable(byte)[] ledger;
}


struct Ledger(H) {
    alias LedgerItem(H) LedgerItemT;
    void append(ref immutable(LedgerItemT) item) {
        sorted=false;
        ledgerlist~=&item;
    }

    void sort() nothrow {
        if ( !sorted ) {
            sort!( (a, b) => (a < b))(ledgerlist);
            sorted=true;
        }
    }
    immutable(byte)[] payload() nothrow {
        immutable(byte)[] _payload;
        sort;
        foreach(item; ledgerlist) {
            payload~=item.data;
        }
        return payload;
    }
private:
    immutable(LedgerItemT)*[] ledgerlist;
    bool sorted;
}

struct BiscuitBlock(H, Consensus) {
    enum long timeCorrection = 0; // Adjust time to newyears 2017 TBD
    enum long Epoch2017=
        TimeSpan.Epich1970 +
        TimeSpan.TicksPerDay * TimeSpan.TickPerYear * 47 + timeCorrection;
    enum Time bitcuitEpoch = Time(Epoch2017);
    enum TimeSpan blockPeriod = TimeSpan.TickPerSecond;
    immutable(H) previousBlock;
    immutable(long) blockCount;
    immutable(Time) time;
    immutable(uint) blockversion;
    immutable(H) ledgerIndex;
    immutable(H) applicationIndex;
    /**
       Valid check is the hash is valid minded value
     */
    alias function bool(const(H) h) const pure nothrow Valid;
    this(
        immutable(BitcuitBlock(H)) block,
        immutable(H) lederIndex,
        immutable(H) applicationIndex,
        Concensus concenus;
        Valid valid  ) {
        this.previousBlock = H(block);
        this.blockCount = block.blockCount + 1;
        this.time = block.time + blockPeriod;
        this.ledgerIndex = lederIndex;
        this.applicationIndex = applicationIndex;
        this.valid = &valid;
    }
    @property immutable(H) Nounce() const pure nothrow {
        return nounce;
    }
    @property immutable(H) blockLock() const nothrow {
        if ( Valid(blockLock) ) {
            return assumeUnique(blockLock);
        }
        else {
            immutable(byte)[] p=payload;
            p~=(cast(byte[])nounce).idup;
            blockLock = H(p);
            return blockLock.idup;
        }
    }
    @property void Nounce(const(byte)[] nounce)
        in {
            assert(this.nounce.sizeof == nounce.length,
                "Byte size of nounce is wrong");
        }
    body {
        this.nounce = nounce;
    }

private:
    immutable(byte)[] payload() const pure nothrow {
        immutable(byte)[] p;
        p~=cast(immutable(byte)[])previousBlock;
        p~=cast(immutable(byte)[])blockCount;
        p~=cast(immutable(byte)[])time;
        p~=cast(immutable(byte)[])legerIndex;
        p~=cast(immutable(byte)[])applicationIndex;
    }
    H nounce;
    H blockLock;
    H blockHash;
    /**
       The valid function checks if
     */
    Valid valid;
    /**
       mined is true when block is a valid minded block
     */
    bool mined;
}

@safe
class BakingSheet(T : CoockieSheet) {
    private const(T) sheet;
    this(immutable(T) sheet) {
        sheet = this.sheet;
    }



}
