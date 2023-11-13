module tagion.betterC.utils.Miscellaneous;

import std.range.primitives : isInputRange;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.betterC.utils.Memory;

// import std.algorithm : map;
// import std.array : array;
import std.algorithm.iteration : cumulativeFold, fold;
import tagion.betterC.utils.BinBuffer;

void gene_xor(ref scope ulong[] result, scope const(ubyte[]) a, scope const(ubyte[]) b)
in {
    assert(a.length == b.length);
    assert(result.length == b.length);
}
do {
    foreach (i, ref r; result) {
        r = a[i] ^ b[i];
    }
}

protected Buffer _xor(const(ubyte[]) a, const(ubyte[]) b)
in {
    assert(a.length == b.length);
    assert(a.length % ulong.sizeof == 0);
}
do {
    ulong[] res;
    res.create(a.length);
    gene_xor(res, a, b);
    return cast(Buffer) res;
}

@trusted
const(Buffer) xor(scope const(ubyte[]) a, scope const(ubyte[]) b)
in {
    assert(a.length == b.length);
    assert(a.length % ulong.sizeof == 0);
}
do {
    ulong[] res;
    res.create(a.length);
    gene_xor(res, a, b);
    return cast(Buffer) res;
}

@trusted
const(Buffer) xor(BinBuffer a, BinBuffer b)
in {
    assert(a.length == b.length);
    assert(a.length % ulong.sizeof == 0);
}
do {
    return xor(a.serialize, b.serialize);
}

@trusted
Buffer xor(ref scope ubyte[] result, scope const(ubyte[]) a, scope const(ubyte[]) b)
in {
    assert(a.length == b.length);
    assert(a.length % ulong.sizeof == 0);
}
do {
    ulong[] res;
    res.create(a.length);
    gene_xor(res, a, b);

    return cast(Buffer) res;
}

@trusted
Buffer xor(Range)(scope Range range) if (isInputRange!Range) {
    import std.array : array;
    import std.range : tail;

    return range
        .cumulativeFold!((a, b) => _xor(a, b))
        .tail(1)
        .front;
}
