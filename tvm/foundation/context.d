module foundation.context;
import std.stdio;

@safe:
struct Context {
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
        data.length = 64 * n;
    }

    template load(uint _align, uint _offset, T, U = T) {
        T load(const int idx) @trusted {
            enum byte_align = 1 << _align;
            const effective_addr = idx + _offset;
            assert(effective_addr + U.sizeof <= data.length, "Out of memory");
            const addr = cast(U*)(&data[effective_addr]);
            writefln("data = %(%02x %)", data[0 .. 10]);
            writefln("load %d = *addr=%f %x", idx, *addr, addr);
            return cast(T)(*addr);
        }
    }

    void store(uint _align, uint _offset, T, U = T)(int idx, U x) @trusted {
        enum byte_align = 1 << _align;
        const effective_addr = idx + _offset;
        writefln("store %d %f", idx, x);
        assert(effective_addr + U.sizeof <= data.length, "Out of memory");
        auto addr = cast(T*)(&data[effective_addr]);
        (*addr) = x;
        writefln("STORE %d = *addr=%f %x", idx, *addr, addr);
    }
}

static Context ctx;
