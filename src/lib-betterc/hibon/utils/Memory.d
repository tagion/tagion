module hibon.utils.Memory;

import std.traits : isArray, ForeachType, isPointer, PointerTarget;
import core.stdc.stdlib : calloc,  realloc, free;
import core.stdc.stdio;

extern(C):
@nogc:

T create(T)(const size_t size) if(isArray!T) {
    alias BaseT=ForeachType!T;
    return (cast(BaseT*)calloc(size, BaseT.sizeof))[0..size];
}

void create(T)(ref T data, const size_t size) if(isArray!T) {
    alias BaseT=ForeachType!T;
    data=(cast(BaseT*)calloc(size, BaseT.sizeof))[0..size];
}


T create(T)() if (isPointer!T) {
    return cast(T)calloc(PointerTarget!(T).sizeof, 1);
}

void resize(T)(ref T data, const size_t len) if(isArray!T) {
    alias BaseT=ForeachType!T;
    const size=len*BaseT.sizeof;
    data=(cast(BaseT*)realloc(data.ptr, size))[0..len];
}

@nogc void dispose(T)(ref T die) if (isArray!T) {
    static if(__traits(compiles, die[0].dispose)) {
        foreach(ref d; die) {
            d.dispose;
        }
    }
    free(die.ptr);
    die=null;
}

@nogc void dispose(T)(ref T die) if (isPointer!T) {
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
        }
        foreach(a; array) {
            printf("a=%d\n", a);
            assert(a == a.init);
        }


        foreach(i, c; table) {
            array[i]=c;
            printf("a=%d\n", c);
        }

        foreach(i, a; array) {
            printf("%d a=%d table[i]=%d\n", i, a, table[i]);
            assert(a == table[i]);
        }
        assert(array.length == table.length);
    }
//    printf("array[0]=%d\n", array[0]);

}
