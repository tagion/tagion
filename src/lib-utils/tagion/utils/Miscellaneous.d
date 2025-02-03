/// Miscellaneous functions
module tagion.utils.Miscellaneous;

import std.algorithm;
import std.array;
import std.range;
import std.traits;
import std.exception;
import std.string : representation;
import std.range.primitives : isInputRange;
import tagion.basic.Types : Buffer, isBufferType;
import tagion.errors.tagionexceptions;

@safe:

Buffer xor(scope const(ubyte[]) a, scope const(ubyte[]) b) pure nothrow
in {
    assert(a.length == b.length);
    assert(a.length % ulong.sizeof == 0);
}
do {
    import tagion.utils.Gene : gene_xor;

    const _a = cast(const(ulong[])) a;
    const _b = cast(const(ulong[])) b;
    return (() @trusted => cast(Buffer) gene_xor(_a, _b))();
}

@nogc
void xor(ref scope ubyte[] result, scope const(ubyte[]) a, scope const(ubyte[]) b) pure nothrow
in {
    assert(a.length == b.length);
    assert(a.length % ulong.sizeof == 0);
}
do {
    import tagion.utils.Gene : gene_xor;

    const _a = cast(const(ulong[])) a;
    const _b = cast(const(ulong[])) b;
    auto _result = cast(ulong[]) result;
    gene_xor(_result, _a, _b);
}

Buffer xor(Range)(Range range) pure if (isInputRange!Range && is(ElementType!Range : const(ubyte[])))
in (!range.empty, "Can not take a xor of an empty range")
do {
    import std.array : array;
    import std.range : tail;

    auto result = new ubyte[range.front.length];
    range
        .each!(b => result[] ^= b[]);
    return (() @trusted => assumeUnique(result))();
}
