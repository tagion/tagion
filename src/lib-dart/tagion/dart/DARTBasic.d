module tagion.dart.DARTBasic;

static T convertFromBuffer(T)(const(ubyte[]) data) pure nothrow @safe {
    if (data.length is 0) {
        return 0;
    }
    import std.bitmanip : bigEndianToNative;

    assert(data.length == T.sizeof);
    return bigEndianToNative!T(data[0 .. T.sizeof]);
}
