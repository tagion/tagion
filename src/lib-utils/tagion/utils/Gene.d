module tagion.utils.Gene;

import std.algorithm.iteration : fold;
import std.exception : assumeUnique;
import std.range : lockstep;

@nogc @safe
uint gene_count(const ulong bitstring) pure nothrow {
    static uint count_ones(ulong BITS = ulong.sizeof * 8)(const ulong x) pure nothrow {
        static if (BITS == 1) {
            return x & 0x1;
        }
        else if (x == 0) {
            return 0;
        }
        else {
            enum HALF_BITS = BITS / 2;
            enum MASK = ulong(1UL << (HALF_BITS)) - 1;
            return count_ones!(HALF_BITS)(x & MASK) + count_ones!(HALF_BITS)(x >> HALF_BITS);
        }
    }

    return count_ones(bitstring);
}

@safe
unittest {
    enum SIZE_BITS = ulong.sizeof * 8;
    {
        const bits = cast(ulong) 0;
        assert(bits.gene_count == 0);
    }
    {
        const bits = cast(ulong) long(-1);
        assert(bits.gene_count == SIZE_BITS);
    }
    {
        const a_bits = ulong(
                0b00001000_00010000_00000100_00100000_00000001_00001000_10000000_00000010UL);
        const b_bits = ulong(
                0b00101000_00010110_00100100_00100111_11110001_01001000_10011000_01100010);
        assert(a_bits.gene_count == 8);
        assert(b_bits.gene_count == 24);
    }
}

@nogc @safe
uint gene_count(scope const(ulong[]) bitstream) pure nothrow {
    return bitstream
        .fold!((a, b) => a + gene_count(b))(uint(0));
}

    @safe
ulong[] gene_xor(scope const(ulong[]) a, scope const(ulong[]) b) pure nothrow {
    auto result = new ulong[a.length];
    gene_xor(result, a, b);
    return result;
}

@nogc @safe
void gene_xor(ref scope ulong[] result, scope const(ulong[]) a, scope const(ulong[]) b) pure nothrow
in {
    assert(a.length == b.length);
    assert(result.length == b.length, "Length of a and b should bed the same");
}
do {
    foreach (i, ref r; result) {
        r = a[i] ^ b[i];
    }
}

@safe
unittest {
    {
        const a_bits = [0b01000001_01101101UL, 0b00010001_10011110UL];
        assert(a_bits.gene_count == 14);
        const b_bits = [0b01011001_00010110UL, 0b01100101_10010011UL];
        assert(b_bits.gene_count == 15);
        ulong[] result;
        result.length = a_bits.length;
        gene_xor(result, a_bits, b_bits);
        assert(result == [0b00011000_01111011UL, 0b01110100_00001101]);
        assert(result.gene_count == 15);
    }
}
