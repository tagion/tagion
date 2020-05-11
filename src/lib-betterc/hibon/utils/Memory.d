module hibon.utils.Memory;

import std.traits : isArray, ForeachType, isPointer, PointerTarget, Unqual;
import core.stdc.stdlib : calloc,  realloc, free;
import core.stdc.stdio;
import std.conv : emplace;

extern(C):
@nogc:

T create(T)(const size_t size) if(isArray!T) {
    alias BaseT=ForeachType!T;
    return (cast(BaseT*)calloc(size, BaseT.sizeof))[0..size];
}

void create(T)(ref T data, const size_t size) if(isArray!T)
    in {
        assert(data is null);
    }
do {
    alias BaseT=ForeachType!T;
    data=(cast(BaseT*)calloc(size, BaseT.sizeof))[0..size];
}

void create(U)(ref U[] data, const(U[]) src) //{ //if (isArray!T && ForeachE
    in {
        assert(data is null);
    }
do {
    alias BaseU=Unqual!U;
    auto temp=(cast(BaseU*)calloc(src.length, U.sizeof))[0..src.length];
    temp[0..src.length]=src;
    data=cast(U[])temp;
}

T* create(T, Args...)(Args args) if(is(T == struct)) {
    auto result=cast(T*)calloc(T.sizeof, 1);
    emplace!T(result, args);
    return result;
}

T create(T)() if (isPointer!T) {
    return cast(T)calloc(PointerTarget!(T).sizeof, 1);
}

void resize(T)(ref T data, const size_t len) if(isArray!T) {
    alias BaseT=ForeachType!T;
    const size=len*BaseT.sizeof;
    data=(cast(BaseT*)realloc(data.ptr, size))[0..len];
}

void dispose(T)(ref T die) if (isArray!T) {
    static if(__traits(compiles, die[0].dispose)) {
        foreach(ref d; die) {
            d.dispose;
        }
    }
    free(die.ptr);
    die=null;
}

void dispose(T)(ref T die) if (isPointer!T) {
    free(die);
    die=null;
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
