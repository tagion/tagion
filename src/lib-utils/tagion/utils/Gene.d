module tagion.utils.Gene;

import std.exception: assumeUnique;

@nogc @safe
uint gene_count(const size_t bitstring) pure nothrow {
    static uint count_ones(size_t BITS = size_t.sizeof * 8)(const size_t x) pure nothrow {
        static if (BITS == 1) {
            return x & 0x1;
        }
        else if (x == 0) {
            return 0;
        }
        else {
            enum HALF_BITS = BITS / 2;
            enum MASK = size_t(1UL << (HALF_BITS)) - 1;
            return count_ones!(HALF_BITS)(x & MASK) + count_ones!(HALF_BITS)(x >> HALF_BITS);
        }
    }

    return count_ones(bitstring);
}

@nogc @safe uint gene_count(scope const(ulong[]) bitstream) pure nothrow
{
    uint result;
    foreach (x; cast(const(size_t[])) bitstream) {
        result += gene_count(x);
    }
    return result;
}

@trusted
immutable(ulong[]) gene_xor(scope const(ulong[]) a, scope const(ulong[]) b) pure nothrow
in {
    assert(a.length == b.length);
}
do {
    auto result = new ulong[a.length];
    gene_xor(result, a, b);
    return assumeUnique(result);
}

@nogc @safe
void gene_xor(ref scope ulong[] result, scope const(ulong[]) a, scope const(ulong[]) b) pure nothrow
in {
    assert(a.length == b.length);
    assert(result.length == b.length);
}
do {
    foreach (i, ref r; result) {
        r = a[i] ^ b[i];
    }
}
