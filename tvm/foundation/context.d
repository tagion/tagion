module foundation.context;
import std.stdio;
import foundation.error;

@safe:
struct Context {
    enum page_size = 0x1_0000;
    private {
        byte[] data;
    }
    /** 
     * Sets the memory
     * Params:
     *   n = min block size
     *   m = max block size
     */
    void set(const uint n, const uint m) {
        data.length = page_size * n;
    }

    T load(size_t _align, size_t _offset, T, U = T)(const int idx) @trusted {
            enum byte_align = 1 << _align;
            const effective_addr = idx + _offset;
            error((idx>=0) && (effective_addr + U.sizeof <= data.length), "Out of memory");
            const addr = cast(U*)(&data[effective_addr]);
            return cast(T)(*addr);
        }

    void store(uint _align, uint _offset, T, U = T)(int idx, U x) @trusted {
        enum byte_align = 1 << _align;
        const effective_addr = idx + _offset;
        error((idx>=0) && (effective_addr + U.sizeof <= data.length), "Out of memory");
        auto addr = cast(T*)(&data[effective_addr]);
        (*addr) = x;
    }
    
    void set_data(const int idx, const(char[]) _data) {
        data[idx..idx+_data.length] = cast(const(byte[]))_data;
    }
}

static Context ctx;
