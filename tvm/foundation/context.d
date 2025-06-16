module foundation.context;
import std.stdio;
@safe:
struct Context {
    private {
        size_t[] data;
        byte[] mem_i8;
        short[] mem_i16;
        int[] mem_i32;
        long[] mem_i64;
    }
    /** 
     * Sets the memory
     * Params:
     *   n = min block size
     *   m = max block size
     */
    void set(const uint n, const uint m) {
        data.length = (64 / size_t.sizeof) * n;
        mem_i8 = cast(byte[]) data;
        mem_i16 = cast(short[]) data;
        mem_i32 = cast(int[]) data;
        mem_i64 = cast(long[]) data;
    }

    template load(uint _align, uint _offset, T, U = T) {
        T load(const int idx) @trusted {
            const effective_addr=_align*idx+_offset;
            static if (_align == 1) {
                assert(idx + _offset + T.sizeof <= mem_i8.length, "Out of memory");
                const addr = cast(U*)&mem_i8[idx + _offset];
                return cast(T)*addr;
            }
            else static if (_align is 2) {
                static if ((T.sizeof == int.sizeof) && (_offset == 0)) {
                    return cast(T) mem_i32[idx];
                }
                else {
                    assert(idx + _offset + T.sizeof / int.sizeof <= mem_i32.length, "Out of memory");
                    const addr = cast(U*)&mem_i32[idx + _offset];
                    return cast(T)*addr;

                }
            }
            else static if (_align is 4) {
                static if ((T.sizeof == long.sizeof) && (_offset == 0)) {
                    writefln("%d align=%d idx=%d x=%s", __LINE__, _align, idx, cast(T)mem_i64[idx]);
                    return cast(T) mem_i64[idx];
                }
                else {
                    assert(idx + _offset + T.sizeof / long.sizeof <= mem_i64.length, "Out of memory");
                    const addr = cast(U*)&mem_i64[idx + _offset];
                    writefln("%d align=%d idx=%d x=%s -- %s", __LINE__, _align, idx, cast(T)mem_i64[idx], T.stringof);
                    return cast(T)*addr;

                }
            }
            else static if (_align is 8) {
                static if ((T.sizeof == long.sizeof) && (_offset == 0)) {
                    return cast(T) mem_i64[idx];
                }
                else {
                    assert(idx + _offset + T.sizeof / long.sizeof <= mem_i64.length, "Out of memory");
                    const addr = cast(U*)&mem_i64[idx + _offset];
                    return cast(T)*addr;

                }
            }

            else {
                import std.format;

                static assert(0, format("Load align %s value not supported", _align));
            }
        }
    }

    void store(uint _align, uint _offset, T, U=T)(int idx, U x) @trusted {
        import std.format;
        static assert(_offset == 0, format("Store with offset %d not yet implemented", _offset));
        static if (_align is 1) {
            assert(idx + _offset + T.sizeof <= mem_i8.length, "Out of memory");
            auto addr = cast(T*)&mem_i8[idx + _offset];
            *addr = x;
        }
        else static if (_align is 2) {
            static if ((T.sizeof is int.sizeof) && (_offset is 0)) {
                auto addr=cast(U*)(&mem_i32[idx]);
                *addr = x; 
                writefln("%s idx=%d x=%a *addr=%a", __FUNCTION__, idx, x, *addr);
            }
            else static if ((T.sizeof is long.sizeof) && (_offset is 0)) {
                auto addr=cast(U*)(&mem_i64[idx]);
                *addr = x;
            }
            else {
                static assert(0, format("Not implemented yet for %s align=%d offset=%d", 
                    T.stringof, _align, _offset));
            }
        }
        else static if (_align is 4) {
            static if (T.sizeof == long.sizeof) {
            }
            else {
                assert(idx + _offset + T.sizeof <= mem_i64.length, "Out of memory");
            }
        }
        else static if (_align is 8) {
            static if (T.sizeof == long.sizeof) {
            }
            else {
                assert(idx + _offset + T.sizeof <= mem_i64.length, "Out of memory");
            }
        }
        else {
            import std.format;

            static assert(0, format("Store align %s value not supported", _align));
        }
    }
}

static Context ctx;
