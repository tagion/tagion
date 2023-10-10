module tagion.basic.Types;

import std.typecons : Typedef, TypedefType;
import std.traits : Unqual;

@safe:
enum BillType {
    NON_USABLE,
    TAGIONS,
    CONTRACTS
}

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

Unqual!T mut(T)(T buf) nothrow pure @nogc if (is(TypedefType!(T) : Buffer)) {
    return Unqual!T(cast(Buffer) buf);
}

unittest {
    const(MyBuf) buf = [1, 2, 3, 4];
    MyBuf mut_buf = buf.mut;
}
/++
 Genera signal
+/
enum Control {
    LIVE = 1, /// Send to the ownerTid when the task has been started
    STOP, /// Send when the child task to stop task
    //    FAIL,   /// This if a something failed other than an exception
    END /// Send for the child to the ownerTid when the task ends
}

private import std.range;

//private std.range.primitives;
version (none) string fileExtension(string path) {
    import std.path : extension;

    return path.extension;
}

version (none) unittest {
    import tagion.basic.Types : FileExtension;
    import std.path : setExtension;

    // assert(!"somenone_invalid_file.extension".fileExtension);
    immutable valid_filename = "somenone_valid_file".setExtension(FileExtension.hibon);
    assert(valid_filename.fileExtension);
    assert(valid_filename.fileExtension == FileExtension.hibon);
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
    recchainblock = ".rcb", /// Recorder chain block file format
    epochdumpblock = ".epdmp", /// Epoch dump chain block file format
    text = ".txt",
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
