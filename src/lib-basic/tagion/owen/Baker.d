/**
   This is the mining module ]
   called the baker
 */

module bakery.owen.Baker;

import tango.time.Time;
private import bakery.owen.BitcuitBlock;
private import bakery.owen.ConcensusBase;

@safe
class Baker(H) {
    alias ConcensusBase!(H) ConcensusT;
    alias BitcuitBlock!(H, ConcensusT) BitcuitBlockT;
    // This function mines the Block
    this(ConcensusT concensus) {
        this.consensus = concensus;
    }
    bool baking(
        immutable(BitcuitBlockT) block,
        immutable(ubyte)[] function() random,
        ref immutable(ubyte)[] buffer,
        Time finish
        ) {
        H blockhash;
        bool found;
        while( (Xtime < finish) && (!found) ) {
            found = heat(block, random(), buffer, blockhash);
        }
        buffer~=blockhash.buffer;
        return found;
    }

private:
    Concensus consensus;
    bool heat(
        immutable(BitcuitBlockT) block,
        immutable(ubyte)[] nounce,
        ref immutable(ubyte)[] buffer,
        out H blockhash) {
        buffer=block.payload;
        buffer~=nounce;
        blockhash=H(buffer);
        return concensus.isBaked(blockhash);
    }
}
