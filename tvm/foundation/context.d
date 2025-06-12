module foundation.context;

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

    template load(uint _align, uint _offset, T) {
        T load(const int idx) @trusted {
            static if (_align == 1) {
                assert(idx + _offset + T.sizeof <= mem_i8.length, "Out of memory");
                const addr = cast(T*)&mem_i8[idx + _offset];
                return *addr;
            }
            else static if (_align == 2) {
                static if ((T.sizeof == int.sizeof) && (_offset == 0)) {
                    return cast(T) mem_i32[idx];
                }
                else {
                    assert(idx + _offset + T.sizeof / int.sizeof <= mem_i32.length, "Out of memory");
                    const addr = cast(T*)&mem_i32[idx + _offset];
                    return *addr;

                }
            }
            else static if (_align == 4) {
                static if ((T.sizeof == long.sizeof) && (_offset == 0)) {
                    return cast(T) mem_i64[idx];
                }
                else {
                    assert(idx + _offset + T.sizeof / long.sizeof <= mem_i64.length, "Out of memory");
                    const addr = cast(T*)&mem_i64[idx + _offset];
                    return *addr;

                }
            }
            else {
                import std.format;

                static assert(0, format("Load align %s value not supported", _align));
            }
        }
    }

    void store(uint _align, uint _offset, T)(int idx, T x) @trusted {
        static if (_align == 2) {
            static if (T.sizeof == int.sizeof) {
                mem_i32[idx] = cast(int) x;
            }
            else static if (T.sizeof == long.sizeof) {
                mem_i64[idx] = cast(long) x;
            }
            else static if (_align == 1) {
                assert(idx + _offset + T.sizeof <= mem_i8.length, "Out of memory");
            }
            else {
                static assert(0, "Not implemented yet");
            }
        }
        else static if (_align == 1) {
            assert(idx + _offset + T.sizeof <= mem_i8.length, "Out of memory");
            auto addr = cast(T*)&mem_i8[idx + _offset];
            *addr = x;
        }
        else static if (_align == 4) {
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
