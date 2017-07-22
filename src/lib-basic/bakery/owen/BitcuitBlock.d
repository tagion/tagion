/**
   This the block in the chain called the BitcuitBlock
 */

module Bakery.Owen.BitcuitBlock;

/**

 */
@safe
struct LedgerItem(H) {
    /**
       Ledger header format.
       struct {
          uint size; // Size in ubytes
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
    this(const(ubyte)[] ledger)
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
    immutable(ubyte)[] data() const pure nothrow {
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
    immutable(ubyte)[] ledger;
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
    immutable(ubyte)[] payload() nothrow {
        immutable(ubyte)[] _payload;
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

/**

 */
struct BitcuitBlock(H, C) {
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
        C concensus
        Valid valid  ) {
        this.previousBlock = H(block);
        this.blockCount = block.blockCount + 1;
        this.time = block.time + blockPeriod;
        this.ledgerIndex = lederIndex;
        this.applicationIndex = applicationIndex;
        this.consensus = consensus;
    }
    @property immutable(H) Nounce() const pure nothrow {
        return nounce;
    }
    @property immutable(H) blockLock() const nothrow {
        if ( consenus.valid(blockLock) ) {
            return assumeUnique(blockLock);
        }
        else {
            immutable(ubyte)[] p=payload;
            p~=(cast(ubyte[])nounce).idup;
            blockLock = H(p);
            return blockLock.idup;
        }
    }
    @property void Nounce(const(ubyte)[] nounce)
        in {
            assert(this.nounce.sizeof == nounce.length,
                "Byte size of nounce is wrong");
        }
    body {
        this.nounce = nounce;
    }

private:
    immutable(ubyte)[] payload() const pure nothrow {
        immutable(ubyte)[] p;
        p~=cast(immutable(ubyte)[])previousBlock;
        p~=cast(immutable(ubyte)[])blockCount;
        p~=cast(immutable(ubyte)[])time;
        p~=cast(immutable(ubyte)[])legerIndex;
        p~=cast(immutable(ubyte)[])applicationIndex;
    }
    H nounce;
    H blockLock;
    H blockHash;
    /**
       The valid function checks if
     */
    C consensus;

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
