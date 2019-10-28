module tagion.utils.Gene;

@safe
uint gene_count(const size_t bitstring) pure nothrow {
     static uint count_ones(size_t BITS=size_t.size*8)(const size_t x) pure nothrow {
         static if ( BITS == 1 ) {
             return x & 0x1;
         }
         else if ( x == 0 ) {
             return 0;
         }
         else {
             enum HALF_BITS=BITS/2;
             enum MASK=(1 << (HALF_BITS))-1;
             return count_ones!(HALF_BITS)(x & MASK) + count_ones!(HALF_BITS)(x >> HALF_BITS);
         }
     }
     return count_ones(bitstream);
}

@safe
uint gene_count(const(ulong[]) bitstream) pure {

    uint result;
    foreach(x; cast(const(size_t[]))bitstream) {
        result+=gene_count(x);
    }
}

@trusted
immutable(ulong[]) gene_xor(const(ulong[]) a, const(ulong[]) b) pure
in {
     assert(a.length == b.length);
}
do {
    return a[]^b[];
}
