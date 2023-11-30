module tagion.network.ReceiveBuffer;

import std.typecons : Tuple;

import LEB128 = tagion.utils.LEB128;

@safe:

struct ReceiveBuffer {
    ubyte[] buffer; /// Allocated buffer
    ptrdiff_t size; /// Buffer size
    size_t total_size; /// Buffer size
    size_t pos;
    enum LEN_MAX = LEB128.calc_size(uint.max);
    pragma(msg, "ReceiveBuffer size FIXME VERY IMPORTANT");
    enum START_SIZE = 0x400;
    static size_t max_size = 0x4000;
    alias Receive = ptrdiff_t delegate(scope void[] buf) nothrow @safe;
    alias ResultBuffer = Tuple!(ptrdiff_t, "size", ubyte[], "data");

    const(ResultBuffer) opCall(const Receive receive) nothrow {
        if (buffer is null) {
            buffer = new ubyte[START_SIZE];
        }
        size_t _pos;
        size_t total_size;
        for (;;) {
            const len = receive(buffer[_pos .. $]);
            if (len == 0) {
                return ResultBuffer(len, buffer[0 .. _pos]);
            }
            if (len < 0) {
                return ResultBuffer(len, buffer[0 .. _pos]);
            }

            if (total_size == 0) {
                if (LEB128.isCompleat(buffer[0.._pos])) {
                    const leb128_len = LEB128.decode!size_t(buffer);
                    total_size = leb128_len.value + leb128_len.size;

                    if (buffer.length <= total_size) {
                        buffer.length = total_size;
                    }
                }
            }
            _pos += len;

        }
        assert(0);
    }

    const(ResultBuffer) append(const Receive receive) {
        if (buffer is null) {
            buffer = new ubyte[START_SIZE];
        }
        if (pos == 0) {
            /// Buffer start
            const len = receive(buffer);
            if (len <= 0) {
                // Connection closed
                return ResultBuffer(len, null);
            }
            const leb128_len = LEB128.decode!uint(buffer);
            total_size = leb128_len.value + leb128_len.size;
            if (total_size >= buffer.length) {
                if (total_size > max_size) {
                    /// Buffer size excees the max allowed size
                    return ResultBuffer(-1, null);
                }
                buffer.length = total_size;
            }
            if (total_size == len) {
                /// Received the whole buffer in one go 
                size = 0;
                pos = 0;
                return ResultBuffer(len, buffer[0 .. len]);
            }
            pos = size = len;
            return ResultBuffer(len, null);
        }
        const len = receive(buffer[pos .. $]);
        if (len <= 0) {
            return ResultBuffer(-1, null);
        }
        size += len;
        if (size >= total_size) {
            scope (exit) {
                pos = size = total_size = 0;
            }
            return ResultBuffer(0, buffer[0 .. total_size]);
        }
        return ResultBuffer(0, null);
    }
}

version (unittest) {
    import tagion.hibon.Document;
    import std.algorithm;
    import tagion.hibon.HiBONRecord;
    import std.array;
    import std.range;
    import std.format;

    @safe
    struct TestStream {
        const(void)[] buffer;
        size_t chunck;
        uint count;
        this(const(ubyte[]) buf) {
            buffer = buf;
        }

        ptrdiff_t receive(scope void[] buf) nothrow {
            const _chunck = (count < 3) ? 1 : chunck;
            count++;
            const len = (() @trusted => cast(ptrdiff_t) min(_chunck, buf.length, buffer.length))();
            if (len >= 0) {
                (() @trusted {
                    buf[0 .. len] = buffer[0 .. len];
                })();
                buffer = buffer[len .. $];
                return len;
            }
            return -1;
        }
    }

    @safe
    struct TestData {
        string[] texts;
        mixin HiBONRecord;
    }
}
unittest {
    static TestStream teststream;
    TestData testdata;
    testdata.texts = iota(17).map!((i) => format("Some text %d", i)).array;

    teststream = TestStream(testdata.serialize);
    teststream.chunck = 0x100;
    ReceiveBuffer receive_buffer;
    {
        const result_buffer = receive_buffer(&teststream.receive);
        assert(result_buffer.data == testdata.serialize);
    }

    testdata.texts = iota(120).map!((i) => format("Some text %d", i)).array;
    teststream = TestStream(testdata.serialize);
    teststream.chunck = 0x100;
        assert(testdata.serialize.length > receive_buffer.START_SIZE,
                "Test data should large than START_SIZE");
    {
        const result_buffer = receive_buffer(&teststream.receive);
        assert(result_buffer.data == testdata.serialize);
    }
}
