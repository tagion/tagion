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
            static if (_align == 2) {
                static if (T.sizeof == int.sizeof) {
                    return mem_i32[idx];
                }
                else {
                    static assert(00, "Not implemented yet");
                }
            }
            else {
                static assert(0, "Align value not supported");
            }
        }
    }
}

static Context ctx;
