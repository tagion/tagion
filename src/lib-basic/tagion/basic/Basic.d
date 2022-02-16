module tagion.basic.Basic;

private import std.string: format, join, strip;
private import std.traits;
private import std.exception: assumeUnique;
import std.bitmanip: BitArray;
import std.meta: AliasSeq;
import std.range.primitives: isInputRange;

enum this_dot = "this.";

import std.conv;

import std.typecons: Typedef, TypedefType;

enum BufferType {
    PUBKEY, /// Public key buffer type
    PRIVKEY, /// Private key buffer type
    SIGNATURE, /// Signature buffer type
    HASHPOINTER, /// Hash pointre buffer type
    MESSAGE, /// Message buffer type
    PAYLOAD /// Payload buffer type
}

enum BillType {
    NON_USABLE,
    TAGIONS,
    CONTRACTS
}

alias Buffer = immutable(ubyte)[]; /// General buffer
alias Pubkey = Typedef!(Buffer, null, BufferType.PUBKEY.stringof); // Buffer used for public keys
alias Signature = Typedef!(Buffer, null, BufferType.SIGNATURE.stringof);
alias Privkey = Typedef!(Buffer, null, BufferType.PRIVKEY.stringof);

alias Payload = Typedef!(Buffer, null, BufferType.PAYLOAD.stringof); // Buffer used fo the event payload
version (none) {
    alias Message = Typedef!(Buffer, null, BufferType.MESSAGE.stringof);
    alias HashPointer = Typedef!(Buffer, null, BufferType.HASHPOINTER.stringof);
}

/+
 Returns:
 true if T is a buffer
+/
enum isBufferType(T) = is(T : const(ubyte[])) || is(TypedefType!T : const(ubyte[]));

static unittest {
    static assert(isBufferType!(immutable(ubyte[])));
    static assert(isBufferType!(immutable(ubyte)[]));
    static assert(isBufferType!(Pubkey));
}

unittest {
    immutable buf = cast(Buffer) "Hello";
    immutable pkey = Pubkey(buf);
}

/++
 Returns:
 a immuatble do
+/
immutable(BUF) buf_idup(BUF)(immutable(Buffer) buffer) {
    return cast(BUF)(buffer.idup);
}

/++
   Returns:
   The position of first '.' in string and
 +/
template find_dot(string str, size_t index = 0) {
    static if (index >= str.length) {
        enum zero_index = 0;
        alias zero_index find_dot;
    }
    else static if (str[index] == '.') {
        enum index_plus_one = index + 1;
        static assert(index_plus_one < str.length, "Static name ends with a dot");
        alias index_plus_one find_dot;
    }
    else {
        alias find_dot!(str, index + 1) find_dot;
    }
}

enum BITARRAY_MESSAGE = "Use tagion.utils.BitMask instead";
/++
 Creates a new clean bitarray
+/
deprecated(BITARRAY_MESSAGE) void bitarray_clear(out BitArray bits, const size_t length) @trusted pure nothrow {
    bits.length = length;
}

/++
 Change the size of the bitarray
+/
deprecated(BITARRAY_MESSAGE) void bitarray_change(ref scope BitArray bits, const size_t length) @trusted {
    bits.length = length;
}

unittest {
    {
        BitArray test;
        immutable uint size = 7;
        test.length = size;
        test[4] = true;
        bitarray_clear(test, size);
        assert(!test[4]);
    }
    {
        BitArray test;
        immutable uint size = 7;
        test.length = size;
        test[4] = true;
        bitarray_change(test, size);
        assert(test[4]);
    }
}

/++
 Countes the number of bits set in mask
+/
uint countVotes(ref const(BitArray) mask) @trusted {
    uint votes;
    foreach (vote; mask) {
        if (vote) {
            votes++;
        }
    }
    return votes;
}

/++
 Wraps a safe version of to!string for a BitArray
 +/
string toText(const(BitArray) bits) @trusted {
    return bits.to!string;
}

template suffix(string name, size_t index) {
    static if (index is 0) {
        alias suffix = name;
    }
    else static if (name[index - 1]!is '.') {
        alias suffix = suffix!(name, index - 1);
    }
    else {
        enum cut_name = name[index .. $];
        alias suffix = cut_name;
    }
}

/++
 Template function returns the suffux name after the last '.'
 +/
template basename(alias K) {
    static if (is(K == string)) {
        enum name = K;
    }
    else {
        enum name = K.stringof;
    }
    enum basename = suffix!(name, name.length);
}

enum nameOf(alias nameType) = __traits(identifier, nameType);

/++
 Returns:
 function name of the current function
+/
mixin template FUNCTION_NAME() {
    import tagion.basic.Basic: basename;

    enum __FUNCTION_NAME__ = basename!(__FUNCTION__)[0 .. $ - 1];
}

unittest {
    enum name_another = "another";
    struct Something {
        mixin("int " ~ name_another ~ ";");
        void check() {
            assert(find_dot!(this.another.stringof) == this_dot.length);
            assert(basename!(this.another) == name_another);
        }
    }

    Something something;
    static assert(find_dot!((something.another).stringof) == something.stringof.length + 1);
    static assert(basename!(something.another) == name_another);
    something.check();
}

/++
 Builds and enum string out of a string array
+/
template EnumText(string name, string[] list, bool first = true) {
    static if (first) {
        enum begin = "enum " ~ name ~ "{";
        alias EnumText!(begin, list, false) EnumText;
    }
    else static if (list.length > 0) {
        enum k = list[0];
        enum code = name ~ k ~ " = " ~ '"' ~ k ~ '"' ~ ',';
        alias EnumText!(code, list[1 .. $], false) EnumText;
    }
    else {
        enum code = name ~ "}";
        alias code EnumText;
    }
}

///
unittest {
    enum list = ["red", "green", "blue"];
    mixin(EnumText!("Colour", list));
    static assert(Colour.red == list[0]);
    static assert(Colour.green == list[1]);
    static assert(Colour.blue == list[2]);

}

/++
 Genera signal
+/
enum Control {
    LIVE = 1, /// Send to the ownerTid when the task has been started
    STOP, /// Send when the child task to stop task
    //    FAIL,   /// This if a something failed other than an exception
    END /// Send for the child to the ownerTid when the task ends
};

/++
 Calculates log2
 Returns:
 log2(n)
 +/
@trusted int log2(ulong n) {
    if (n == 0) {
        return -1;
    }
    import core.bitop: bsr;

    return bsr(n);
}

///
unittest {
    // Undefined value returns -1
    assert(log2(0) == -1);
    assert(log2(17) == 4);
    assert(log2(177) == 7);
    assert(log2(0x1000_000_000) == 36);

}

/++
 Generate a temporary file name
+/
@trusted
string tempfile() {
    import std.file: deleteme;

    int dummy;
    return deleteme ~ (&dummy).to!string;
}

/++
 Returns:
 true if the type T is one of types in the list TList
+/
template isOneOf(T, TList...) {
    static if (TList.length == 0) {
        enum isOneOf = false;
    }
    else static if (is(T == TList[0])) {
        enum isOneOf = true;
    }
    else {
        alias isOneOf = isOneOf!(T, TList[1 .. $]);
    }
}

///
static unittest {
    import std.meta;

    alias Seq = AliasSeq!(long, int, ubyte);
    static assert(isOneOf!(int, Seq));
    static assert(!isOneOf!(double, Seq));
}

/++
   Finds the type in the TList which T can be typecast to
   Returns:
   void if not type is found
 +/
template CastTo(T, TList...) {
    static if (TList.length is 0) {
        alias CastTo = void;
    }
    else {
        alias castT = TList[0];
        static if (is(T : castT)) {
            alias CastTo = castT;
        }
        else {
            alias CastTo = CastTo!(T, TList[1 .. $]);
        }
    }
}

///
static unittest {
    static assert(is(void == CastTo!(string, AliasSeq!(int, long, double))));
    static assert(is(double == CastTo!(float, AliasSeq!(int, long, double))));
    static assert(is(string == CastTo!(string, AliasSeq!(uint, string))));
    static assert(is(uint == CastTo!(ushort, AliasSeq!(uint, string))));
    static assert(is(uint == CastTo!(int, AliasSeq!(string, uint))));
    static assert(is(const(uint) == CastTo!(inout(uint), AliasSeq!(const(uint), const(string)))));
}

enum DataFormat {
    json = "json", // JSON File format
    hibon = "hibon", // HiBON file format
    wasm = "wasm", // WebAssembler binary format
    wast = "wast", // WebAssembler text format
    dartdb = "drt", // DART data-base
}

import std.typecons: Tuple;

alias FileNames = Tuple!(string, "tempdir", string, "filename", string, "fullpath");
const(FileNames) fileId(T)(string ext, string prefix = null) @safe {
    import std.process: environment, thisProcessID;
    import std.file;
    import std.path;
    import std.array: join;

    //import std.traits;
    FileNames names;
    names.tempdir = tempDir.buildPath(environment.get("USER"));
    names.filename = setExtension([prefix, thisProcessID.to!string, T.stringof].join("_"), ext);
    names.fullpath = buildPath(names.tempdir, names.filename);
    names.tempdir.exists || names.tempdir.mkdir;
    return names;
}

template EnumContinuousSequency(Enum) if (is(Enum == enum)) {
    template Sequency(EList...) {
        static if (EList.length is 1) {
            enum Sequency = true;
        }
        else static if (EList[0] + 1 is EList[1]) {
            enum Sequency = Sequency!(EList[1 .. $]);
        }
        else {
            enum Sequency = false;
        }
    }

    enum EnumContinuousSequency = Sequency!(EnumMembers!Enum);
}

static unittest {
    enum Count {
        zero,
        one,
        two,
        three
    }

    static assert(EnumContinuousSequency!Count);

    enum NoCount {
        zero,
        one,
        three = 3
    }

    static assert(!EnumContinuousSequency!NoCount);

    enum OffsetCount {
        one = 1,
        two,
        three
    }

    static assert(EnumContinuousSequency!OffsetCount);
}

/**
 Returns:
 If the range is not empty the first element is return
 else the .init value of the range element type is return
 The first element is returned
*/
template doFront(Range) if (isInputRange!Range) {
    alias T = ForeachType!Range;
    T doFront(Range r) {
        if (r.empty) {
            return T.init;
        }
        return r.front;
    }
}


enum isEqual(T1, T2) = is(T1 == T2);
//enum isUnqualEqual(T1, T2) = is(Unqual!T1 == T2);

unittest {
    import std.traits : Unqual;
    import std.meta : ApplyLeft, ApplyRight;
    static assert(isEqual!(int, int));
    static assert(!isEqual!(int, long));
    alias U = immutable(int);
    static assert(isEqual!(int, Unqual!U));
    alias Left = ApplyLeft!(isEqual, int);
    static assert(Left!(Unqual!U));
}

auto eatOne(R)(ref R r) if (isInputRange!R) {
    scope(exit) {
        r.popFront;
    }
    return r.front;
}
