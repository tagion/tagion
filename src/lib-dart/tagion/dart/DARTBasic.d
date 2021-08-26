module tagion.dart.DARTBasic;

static T convertFromBuffer(T)(const ubyte[] data) {
    if (data == [])
        return 0;
    import std.bitmanip: bigEndianToNative;

    assert(data.length == T.sizeof);
    return bigEndianToNative!T(data[0 .. T.sizeof]);
}
