module tagion.utils.Gene;

import std.exception : assumeUnique;
@safe
uint gene_count(const size_t bitstring) pure nothrow {
     static uint count_ones(size_t BITS=size_t.sizeof*8)(const size_t x) pure nothrow {
         static if ( BITS == 1 ) {
             return x & 0x1;
         }
         else if ( x == 0 ) {
             return 0;
         }
         else {
             enum HALF_BITS=BITS/2;
             enum MASK=size_t(1UL << (HALF_BITS))-1;
             return count_ones!(HALF_BITS)(x & MASK) + count_ones!(HALF_BITS)(x >> HALF_BITS);
         }
     }
     return count_ones(bitstring);
}

@safe
uint gene_count(const(ulong[]) bitstream) pure {
    uint result;
    foreach(x; cast(const(size_t[]))bitstream) {
        result+=gene_count(x);
    }
    return result;
}

@trusted
immutable(ulong[]) gene_xor(const(ulong[]) a, const(ulong[]) b) pure
in {
     assert(a.length == b.length);
}
do {
    auto result=new ulong[a.length];
    gene_xor(result, a, b);
    return assumeUnique(result);
}

@trusted
void gene_xor(ref ulong[] result, const(ulong[]) a, const(ulong[]) b) pure
in {
     assert(a.length == b.length);
     assert(result.length == b.length);
}
do {
    foreach(i, ref r; result) {
        r=a[i]^b[i];
    }
}
