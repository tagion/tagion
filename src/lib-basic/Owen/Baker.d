/**
   This is the mining module ]
   called the baker
 */

module Bakery.Owen.Baker;

import Tango.time.Time;
private import Bakery.Owen.BitcuitBlock;

@safe
interface Concensus {

}

@safe
class Baker(H, C) {
    alias BitcuitBlock!(H, C) BitcuitBlockT;
    // This function mines the Block
    bool baking(
        immutable(BitcuitBlockT) block,
        function immutable(ubyte)[] random,
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
    bool heat(
        immutable(BitcuitBlockT) block,
        immutable(ubyte)[] nounce,
        ref immutable(ubyte)[] buffer,
        out H blockhash) {
        buffer=block.payload;
        buffer~=nounce;
        blockhash=H(buffer);
        return C.isBaked(blockhash);
    }
    immutable(ubyte)[] buffer;
    H blockhash;
}
