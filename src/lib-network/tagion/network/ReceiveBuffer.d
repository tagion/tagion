module tagion.network.ReceiveBuffer;

import std.typecons : Tuple;

import LEB128 = tagion.utils.LEB128;

@safe:

struct ReceiveBuffer {
    ubyte[] buffer; /// Allocated buffer
    enum LEN_MAX = LEB128.calc_size(uint.max);
    enum START_SIZE = 0x400;
    static size_t max_size = 0x4000;
    alias Receive = ptrdiff_t delegate(scope void[] buf) nothrow @safe;
    alias ResultBuffer = Tuple!(ptrdiff_t, "size", ubyte[], "data");

    const(ResultBuffer) opCall(const Receive receive) nothrow {
        if (buffer is null) {
            buffer = new ubyte[START_SIZE];
        }
        size_t pos;
        ptrdiff_t total_size = -1;
        scope (exit) {
        }
        while (total_size < 0 || pos <= total_size) {
            const len = receive(buffer[pos .. $]);
            if (len == 0) {
                return ResultBuffer(pos, buffer[0 .. pos]);
            }
            if (len < 0) {
                return ResultBuffer(len, buffer[0..pos]);
            }
            pos += len;

            if (total_size < 0) {
                if (LEB128.isCompleat(buffer[0 .. pos])) {
                    const leb128_len = LEB128.decode!size_t(buffer);
                    total_size = leb128_len.value + leb128_len.size;
                    if (total_size > max_size) {
                        return ResultBuffer(-2, null);
                    }
                    if (buffer.length <= total_size) {
                        buffer.length = total_size;
                    }
                    if (pos >= total_size) {
                        break;
                    }
                }
            }

        }
        return ResultBuffer(pos, buffer[0 .. total_size]);
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
        size_t chunk;
        uint count;
        this(const(ubyte[]) buf) {
            buffer = buf;
        }

        ptrdiff_t receive(scope void[] buf) nothrow {
            const _chunk = (count < 3) ? 1 : chunk;
            count++;
            const len = (() @trusted => cast(ptrdiff_t) min(_chunk, buf.length, buffer.length))();
            if (len >= 0) {
                (() @trusted { buf[0 .. len] = buffer[0 .. len]; })();
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
    teststream.chunk = 0x100;
    ReceiveBuffer receive_buffer;
    {
        const result_buffer = receive_buffer(&teststream.receive);
        assert(result_buffer.data == testdata.serialize);
    }

    testdata.texts = iota(120).map!((i) => format("Some text %d", i)).array;
    teststream = TestStream(testdata.serialize);
    teststream.chunk = 0x100;
    assert(testdata.serialize.length > receive_buffer.START_SIZE,
            "Test data should large than START_SIZE");
    {
        const result_buffer = receive_buffer(&teststream.receive);
        assert(result_buffer.data == testdata.serialize);
    }
}
