module hibon.Memory;

import std.traits : isArray, ForeachType, isPointer, PointerTarget;
import core.stdc.stdlib : calloc, malloc, realloc, free;

extern(C):
@nogc:

T create(T)(const size_t size) if(isArray!T) {
    alias BaseT=ForeachType!T;
    return (cast(BaseT*)calloc(size, BaseT.sizeof))[0..size];
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
