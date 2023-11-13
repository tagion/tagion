module tagion.betterC.utils.Memory;

import core.stdc.string : memcpy;
import std.conv : emplace;
import std.traits : ForeachType, PointerTarget, Unqual, isArray, isPointer;
import tagion.betterC.utils.platform;

private import tagion.crypto.secp256k1.c.secp256k1;
private import tagion.crypto.secp256k1.c.secp256k1_ecdh;

@nogc:

version (memtrace) {
    enum memalloc_format = "#%p:%06d\t\t\t\t%04d %c %s\n";
    static const memalloc_trace = memalloc_format.ptr;
    enum memfree_format = "#%p:000000\t\t\t\t%04d %c %s\n";
    static const memfree_trace = memfree_format.ptr;
    enum mempos_format = "#%p:%06d\t\t\t\t%d:%s\n";
    static const mempos = mempos_format.ptr;
    static uint block;
}

@trusted
T create(T)(const size_t size, string file = __FILE__, size_t line = __LINE__) if (isArray!T) {
    alias BaseT = ForeachType!T;
    auto mem = calloc(size, BaseT.sizeof);
    version (memtrace) {
        const _size = size * BaseT.sizeof;
        printf(memalloc_trace, mem, _size, block, 'a', T.stringof.ptr);
        printf(mempos, mem, _size, line, file.ptr);
        block++;
    }
    return (cast(BaseT*) mem)[0 .. size];
}

@trusted
void create(T)(ref T data, const size_t size, string file = __FILE__, size_t line = __LINE__) if (isArray!T)
in {
    assert(data is null);
}
do {
    alias BaseT = ForeachType!T;
    auto mem = calloc(size, BaseT.sizeof);
    version (memtrace) {
        const _size = size * BaseT.sizeof;
        printf(memalloc_trace, mem, _size, block, 'A', T.stringof.ptr);
        printf(mempos, mem, _size, line, file.ptr);
        block++;

    }
    data = (cast(BaseT*) mem)[0 .. size];
}

@trusted
void create(U)(ref U[] data, const(U[]) src, string file = __FILE__, size_t line = __LINE__)
in {
    assert(data is null);
}
do {
    alias BaseU = Unqual!U;
    auto mem = calloc(src.length, U.sizeof);
    version (memtrace) {
        printf(memalloc_trace, mem, src.length * U.sizeof, block, 'B', (U[]).stringof.ptr);
        printf(mempos, mem, 0, line, file.ptr);
        block++;

    }
    auto temp = (cast(BaseU*) mem)[0 .. src.length];
    temp[0 .. src.length] = src;
    data = cast(U[]) temp;
}

@trusted
T* create(T, Args...)(Args args, string file = __FILE__, size_t line = __LINE__) if (is(T == struct)) {
    auto mem = calloc(T.sizeof, 1);
    version (memtrace) {
        const _size = T.sizeof;
        printf(memalloc_trace, mem, _size, block, 'S', T.stringof.ptr);
        printf(mempos, mem, _size, line, file.ptr);
        block++;
    }
    auto result = cast(T*) mem;
    emplace!T(result, args);
    return result;
}

@trusted
T create(T)(string file = __FILE__, size_t line = __LINE__) if (isPointer!T) {
    auto mem = calloc(PointerTarget!(T).sizeof, 1);
    version (memtrace) {
        const _size = PointerTarget!(T).sizeof;
        printf(memalloc_trace, mem, _size, block, '*', T.stringof.ptr);
        printf(mempos, mem, _size, line, file.ptr);
        block++;

    }
    return cast(T) mem;
}

@trusted
void resize(T)(ref T data, const size_t len, string file = __FILE__, size_t line = __LINE__) if (isArray!T) {
    alias BaseT = ForeachType!T;
    const size = len * BaseT.sizeof;
    auto mem = realloc(cast(void*) data.ptr, size);
    version (memtrace) {
        printf(memfree_trace, &data, block, 'R', T.stringof.ptr);
        printf(memalloc_trace, mem, size, block, 'R', T.stringof.ptr);
        printf(mempos, mem, size, line, file.ptr);
    }
    data = (cast(BaseT*) mem)[0 .. len];
}

@trusted
void dispose(T)(ref T die, string file = __FILE__, size_t line = __LINE__) if (isArray!T) {
    if (die !is null) {
        static if (__traits(compiles, die[0].dispose)) {
            foreach (ref d; die) {
                d.dispose;
            }
        }
        version (memtrace) {
            block--;
            printf(memfree_trace, die.ptr, block, 'd', T.stringof.ptr);
            printf(mempos, die.ptr, 0, line, file.ptr);
        }
        free(cast(void*) die.ptr);
        die = null;
    }
}

@trusted
void dispose(bool OWNS = true, T)(ref T die, string file = __FILE__, size_t line = __LINE__) if (isPointer!T) {
    if (die !is null) {
        static if (OWNS && __traits(compiles, (*die).dispose)) {
            (*die).dispose;
        }
        version (memtrace) {
            block--;
            printf(memfree_trace, die, block, 'D', T.stringof.ptr);
            printf(mempos, die, 0, line, file.ptr);
        }
        free(die);
        die = null;
    }
}

@trusted
void memcpy_wrapper(T)(ref T desination, T source) {
    if (desination.length == source.length) {
        memcpy(desination, source, source.length);
    }
}

enum SECP256K1 : uint {
    FLAGS_TYPE_MASK = SECP256K1_FLAGS_TYPE_MASK,
    FLAGS_TYPE_CONTEXT = SECP256K1_FLAGS_TYPE_CONTEXT,
    FLAGS_TYPE_COMPRESSION = SECP256K1_FLAGS_TYPE_COMPRESSION,
    /** The higher bits contain the actual data. Do not use directly. */
    FLAGS_BIT_CONTEXT_VERIFY = SECP256K1_FLAGS_BIT_CONTEXT_VERIFY,
    FLAGS_BIT_CONTEXT_SIGN = SECP256K1_FLAGS_BIT_CONTEXT_SIGN,
    FLAGS_BIT_COMPRESSION = FLAGS_BIT_CONTEXT_SIGN,

    /** Flags to pass to secp256k1_context_create. */
    CONTEXT_VERIFY = SECP256K1_CONTEXT_VERIFY,
    CONTEXT_SIGN = SECP256K1_CONTEXT_SIGN,
    CONTEXT_NONE = SECP256K1_CONTEXT_NONE,

    /** Flag to pass to secp256k1_ec_pubkey_serialize and secp256k1_ec_privkey_export. */
    EC_COMPRESSED = SECP256K1_EC_COMPRESSED,
    EC_UNCOMPRESSED = SECP256K1_EC_UNCOMPRESSED,

    /** Prefix byte used to tag various encoded curvepoints for specific purposes */
    TAG_PUBKEY_EVEN = SECP256K1_TAG_PUBKEY_EVEN,
    TAG_PUBKEY_ODD = SECP256K1_TAG_PUBKEY_ODD,
    TAG_PUBKEY_UNCOMPRESSED = SECP256K1_TAG_PUBKEY_UNCOMPRESSED,
    TAG_PUBKEY_HYBRID_EVEN = SECP256K1_TAG_PUBKEY_HYBRID_EVEN,
    TAG_PUBKEY_HYBRID_ODD = SECP256K1_TAG_PUBKEY_HYBRID_ODD
}

@trusted
bool randomize(immutable(ubyte[]) seed)
in {
    assert(seed.length == 32 || seed is null);
}
do {
    secp256k1_context* _ctx;
    // const int flag = 0;
    _ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);
    //        auto ctx=getContext();
    // immutable(ubyte)* _seed = seed.ptr;
    return secp256k1_context_randomize(_ctx, &seed[0]) == 1;
}

unittest {
    { // Check Array
        uint[] array;
        const(uint[6]) table = [5, 6, 7, 3, 2, 1];
        array.create(table.length);
        scope (exit) {
            array.dispose;
            assert(array.length == 0);
            assert(array is null);
        }

        foreach (a; array) {
            assert(a == a.init);
        }

        foreach (i, c; table) {
            array[i] = c;
        }

        foreach (i, a; array) {
            assert(a == table[i]);
        }
        assert(array.length == table.length);
    }

    { // Struct
        struct S {
            bool b;
            int x;
        }

        auto s = create!S(true, 42);
        scope (exit) {
            s.dispose;
        }

        assert(s.b == true);
        assert(s.x == 42);
    }

}
