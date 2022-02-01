module hibon.utils.Memory;

import std.traits : isArray, ForeachType, isPointer, PointerTarget, Unqual;
import hibon.utils.platform;

import std.conv : emplace;
extern(C):
@nogc:

version(memtrace) {
    enum memalloc_format="#%p:%06d\t\t\t\t%04d %c %s\n";
    static const memalloc_trace=memalloc_format.ptr;
    enum memfree_format="#%p:000000\t\t\t\t%04d %c %s\n";
    static const memfree_trace=memfree_format.ptr;
    enum mempos_format="#%p:%06d\t\t\t\t%d:%s\n";
    static const mempos=mempos_format.ptr;
    static uint block;
}

T create(T)(const size_t size, string file=__FILE__, size_t line=__LINE__) if(isArray!T) {
    alias BaseT=ForeachType!T;
    auto mem=calloc(size, BaseT.sizeof);
    version(memtrace) {
        const _size=size*BaseT.sizeof;
        printf(memalloc_trace, mem, _size, block, 'a', T.stringof.ptr);
        printf(mempos, mem, _size, line, file.ptr);
        block++;
    }
    return (cast(BaseT*)mem)[0..size];
}

void create(T)(ref T data, const size_t size, string file=__FILE__, size_t line=__LINE__) if(isArray!T)
    in {
        assert(data is null);
    }
do {
    alias BaseT=ForeachType!T;
    auto mem=calloc(size, BaseT.sizeof);
    version(memtrace) {
        const _size=size*BaseT.sizeof;
        printf(memalloc_trace, mem, _size,  block, 'A', T.stringof.ptr);
        printf(mempos, mem, _size, line, file.ptr);
        block++;

    }
    data=(cast(BaseT*)mem)[0..size];
}

void create(U)(ref U[] data, const(U[]) src, string file=__FILE__, size_t line=__LINE__)
    in {
        assert(data is null);
    }
do {
    alias BaseU=Unqual!U;
    auto mem=calloc(src.length, U.sizeof);
    version(memtrace) {
        printf(memalloc_trace, mem, src.length*U.sizeof,  block, 'B', (U[]).stringof.ptr);
        printf(mempos, mem, 0, line, file.ptr);
        block++;

    }
    auto temp=(cast(BaseU*)mem)[0..src.length];
    temp[0..src.length]=src;
    data=cast(U[])temp;
}

T* create(T, Args...)(Args args, string file=__FILE__, size_t line=__LINE__) if(is(T == struct)) {
    auto mem=calloc(T.sizeof, 1);
    version(memtrace) {
        const _size=T.sizeof;
        printf(memalloc_trace, mem, _size, block, 'S', T.stringof.ptr);
        printf(mempos, mem, _size, line, file.ptr);
        block++;
    }
    auto result=cast(T*)mem;
    emplace!T(result, args);
    return result;
}

T create(T)(string file=__FILE__, size_t line=__LINE__) if (isPointer!T) {
    auto mem=calloc(PointerTarget!(T).sizeof, 1);
    version(memtrace) {
        const _size=PointerTarget!(T).sizeof;
        printf(memalloc_trace, mem, _size, block, '*', T.stringof.ptr);
        printf(mempos, mem, _size, line, file.ptr);
        block++;

    }
    return cast(T)mem;
}

void resize(T)(ref T data, const size_t len, string file=__FILE__, size_t line=__LINE__) if(isArray!T) {
    alias BaseT=ForeachType!T;
    const size=len*BaseT.sizeof;
    auto mem=realloc(data.ptr, size);
    version(memtrace) {
        printf(memfree_trace,  &data, block, 'R', T.stringof.ptr);
        printf(memalloc_trace,  mem, size, block, 'R', T.stringof.ptr);
        printf(mempos, mem, size, line, file.ptr);
    }
    data=(cast(BaseT*)mem)[0..len];
}

void dispose(T)(ref T die, string file=__FILE__, size_t line=__LINE__) if (isArray!T) {
    if (die !is null) {
    static if(__traits(compiles, die[0].dispose)) {
        foreach(ref d; die) {
            d.dispose;
        }
    }
    version(memtrace) {
        block--;
        printf(memfree_trace,  die.ptr, block, 'd', T.stringof.ptr);
        printf(mempos, die.ptr, 0, line, file.ptr);
    }
    free(die.ptr);
    die=null;
    }
}

void dispose(bool OWNS=true, T)(ref T die, string file=__FILE__, size_t line=__LINE__) if (isPointer!T) {
    if (die !is null) {
    static if (OWNS && __traits(compiles, (*die).dispose)) {
        (*die).dispose;
    }
    version(memtrace) {
        block--;
        printf(memfree_trace, die, block, 'D', T.stringof.ptr);
        printf(mempos, die, 0, line, file.ptr);
    }
    free(die);
    die=null;
    }
}

unittest {
    { // Check Array
        uint[] array;
        const(uint[6]) table=[5,6,7,3,2,1];
        array.create(table.length);
        scope(exit) {
            array.dispose;
            assert(array.length == 0);
            assert(array is null);
        }

        foreach(a; array) {
            assert(a == a.init);
        }


        foreach(i, c; table) {
            array[i]=c;
        }

        foreach(i, a; array) {
            assert(a == table[i]);
        }
        assert(array.length == table.length);
    }

    { // Struct
        struct S {
            bool b;
            int x;
        }
        auto s=create!S(true, 42);
        scope(exit) {
            s.dispose;
        }


        assert(s.b == true);
        assert(s.x == 42);
    }

}
