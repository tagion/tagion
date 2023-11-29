module tagion.network.ReceiveBuffer;

import std.typecons : Tuple;

import LEB128 = tagion.utils.LEB128;

@safe
struct ReceiveBuffer {
    ubyte[] buffer; /// Allocated buffer
    ptrdiff_t size; /// Buffer size
    size_t total_size; /// Buffer size
    size_t pos;
    enum LEN_MAX = LEB128.calc_size(uint.max);
    enum START_SIZE = 0x400;
    static size_t max_size = 0x4000;
    alias Receive = ptrdiff_t delegate(void[] buf);
    alias ResultBuffer = Tuple!(ptrdiff_t, "size", ubyte[], "data");

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
