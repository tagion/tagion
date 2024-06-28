/// Basic Types ontop of Buffer
module tagion.basic.Types;

import std.traits : Unqual;
import std.typecons : Typedef, TypedefType;

@safe:

alias Buffer = immutable(ubyte)[]; /// General buffer
/+
 Returns:
 true if T is a const(ubyte)[]
+/
enum isBufferType(T) = is(T : const(ubyte[])) || is(TypedefType!T : const(ubyte[]));
enum isBufferTypedef(T) = is(TypedefType!T : const(ubyte[])) && !is(T : const(ubyte[]));

/*
Returns:
true if T is a Buffer (immutable(ubyte))
*/
enum isBuffer(T) = is(T : immutable(ubyte[])) || is(TypedefType!T : immutable(ubyte[]));

version (unittest) {
    alias MyBuf = Typedef!(Buffer, null, "MyBuf");
}
static unittest {
    static assert(isBufferType!(immutable(ubyte[])));
    static assert(isBufferType!(immutable(ubyte)[]));
    static assert(isBufferType!(const(ubyte)[]));
    static assert(isBufferType!(ubyte[]));
    static assert(!isBufferType!(char[]));
    static assert(isBufferType!(MyBuf));

    static assert(isBufferTypedef!MyBuf);
    static assert(!isBufferTypedef!(const(ubyte)[]));

    static assert(isBuffer!MyBuf);
    static assert(isBuffer!(immutable(ubyte)[]));
    static assert(!isBuffer!(const(ubyte[])));

}

Unqual!T mut(T)(T buf) nothrow pure @nogc @trusted if (is(TypedefType!(T) : Buffer)) {
    return Unqual!T(cast(Buffer) buf);
}

unittest {
    const(MyBuf) buf = [1, 2, 3, 4];
    MyBuf mut_buf = buf.mut;
}

enum FileExtension {
    json = ".json", /// JSON File format
    hibon = ".hibon", /// HiBON file format
    wasm = ".wasm", /// WebAssembler binary format
    wat = ".wat", /// WebAssembler text format
    wast = ".wast", /// WebAssembler superset text format
    wo = ".wo", /// WASM object file
    block = ".blk", /// Block file
    dart = ".drt", /// DART data-base
    markdown = ".md", /// DART data-base
    dsrc = ".d", /// DART data-base
    epochdumpblock = ".epdmp", /// Epoch dump chain block file format
    text = ".txt",
    csv = ".csv", /// Comma-separated values
}

enum DOT = '.'; /// File extension separator

bool hasExtension(const(char[]) filename, const(FileExtension) ext) pure nothrow {
    import std.path : extension;

    return ext == filename.extension;
}

bool hasExtension(const(char[]) filename, const(char[]) ext) pure nothrow {
    import std.path : extension;

    const file_ext = filename.extension;
    return (file_ext == ext) || (file_ext == DOT ~ ext);
}

unittest {
    assert("test.hibon".hasExtension(FileExtension.hibon));
    assert(!"test.hibon".hasExtension(FileExtension.dart));
    assert("test.hibon".hasExtension("hibon"));
    assert("test.hibon".hasExtension(".hibon"));
}

import std.traits : TemplateOf;

enum isTypedef(T) = __traits(isSame, TemplateOf!T, Typedef);

static unittest {
    alias MyInt = Typedef!int;
    static assert(isTypedef!MyInt);
    static assert(!isTypedef!int);
}

enum BASE58Identifier = '@';


import Base58 = tagion.basic.base58;
@trusted
string encodeBase58(const(ubyte[]) data) pure nothrow {
    import std.exception;
    const result = BASE58Identifier ~ assumeWontThrow(Base58.encode((() @trusted => cast(ubyte[]) data)()));
    return result.idup;
}

@trusted 
string encodeBase58(T)(const(T) buf) pure nothrow if (isBufferTypedef!T) {
    return encodeBase58(cast(TypedefType!T) buf);
}


version(none)
unittest {
    const(Buffer) buf = [1, 2, 3];
    const buf_base58 = buf.encodeBase58;
    const(MyBuf) my_buf = [1, 2, 3];
    const my_buf_base58 = my_buf.encodeBase58;
    assert(buf_base58 == "@AQID");
    assert(buf_base58 == my_buf_base58);
}
