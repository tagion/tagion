/// Basic functions used in the tagion project
module tagion.basic.basic;

private import std.string : join;
private import std.traits;
import std.meta : AliasSeq;

enum this_dot = "this.";
import std.conv;

/++
 Returns:
 a immuatble do
+/
immutable(BUF) buf_idup(BUF)(immutable(Buffer) buffer) {
    pragma(msg, "fixme(cbr): looks redundent");
    return cast(BUF)(buffer.idup);
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

enum NameOf(alias nameType) = __traits(identifier, nameType);

/++
 Returns:
 function name of the current function
+/
mixin template FUNCTION_NAME() {
    import tagion.basic.basic : basename;

    enum __FUNCTION_NAME__ = basename!(__FUNCTION__)[0 .. $ - 1];
}

///
unittest {
    enum name_another = "another";
    import std.algorithm.searching : countUntil;

    struct Something {
        mixin("int " ~ name_another ~ ";");
        void check() {
            // Check that basename removes (this.) from the scope name space
            static assert(this.another.stringof.countUntil('.') == this_dot.countUntil('.'));
            static assert(basename!(this.another) == name_another);
        }
    }

    Something something;
    // check that basename work in global scope (not this.)
    static assert(something.stringof.countUntil('.') == -1);
    static assert(basename!(something.another) == name_another);
}
/++
 Builds and enum string out of a string array
+/
template EnumText(string name, string[] list, bool first = true) {
    static if (first) {
        enum begin = "enum " ~ name ~ "{";
        alias EnumText = EnumText!(begin, list, false);
    }
    else static if (list.length > 0) {
        enum k = list[0];
        enum code = name ~ k ~ " = " ~ '"' ~ k ~ '"' ~ ',';
        alias EnumText = EnumText!(code, list[1 .. $], false);
    }
    else {
        enum code = name ~ "}";
        alias EnumText = code;
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
 Calculates log2
 Returns:
 log2(n)
 +/
@trusted int log2(ulong n) {
    if (n == 0) {
        return -1;
    }
    import core.bitop : bsr;

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
    import std.file;
    import std.path;
    import std.random;
    import std.range;

    auto rnd = Random(unpredictableSeed);
    return buildPath(tempDir, generate!(() => uniform('A', 'Z', rnd)).takeExactly(20).array);
}

@safe
void forceRemove(const(string) filename) {
    import std.file : exists, remove;

    if (filename.exists) {
        filename.remove;
    }
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

import std.typecons : Tuple;

alias FileNames = Tuple!(string, "tempdir", string, "filename", string, "fullpath");
const(FileNames) fileId(T)(string ext, string prefix = null) @safe {
    import std.array : join;
    import std.file;
    import std.path;
    import std.process : environment, thisProcessID;

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

///
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

/// isEqual is the same as `is()` function which can be used in template filters 
enum isEqual(T1, T2) = is(T1 == T2);
//enum isUnqualEqual(T1, T2) = is(Unqual!T1 == T2);

unittest {
    import std.meta : ApplyLeft, ApplyRight;
    import std.traits : Unqual;

    static assert(isEqual!(int, int));
    static assert(!isEqual!(int, long));
    alias U = immutable(int);
    static assert(isEqual!(int, Unqual!U));
    alias Left = ApplyLeft!(isEqual, int);
    static assert(Left!(Unqual!U));
}

/// Calling any system functions.
template assumeTrusted(alias F) {
    import std.traits;

    static assert(isUnsafe!F);

    auto assumeTrusted(Args...)(Args args) @trusted {
        return F(args);
    }
}

///
@safe
unittest {
    auto bar(int b) @system {
        return b + 1;
    }

    const b = assumeTrusted!bar(5);
    assert(b == 6);

    // applicable to 0-ary function
    static auto foo() @system {
        return 3;
    }

    const a = assumeTrusted!foo;
    assert(a == 3);

    // // It can be used for alias
    alias trustedBar = assumeTrusted!bar;
    alias trustedFoo = assumeTrusted!foo;
    //    assert(is(typeof(trustedFoo) == function));

    import core.stdc.stdlib;

    auto ptr = assumeTrusted!malloc(100);
    assert(ptr !is null);
    ptr.assumeTrusted!free;

    ptr = assumeTrusted!calloc(10, 100);
    ptr.assumeTrusted!free;

    alias lambda = assumeTrusted!((int a) @system => a * 3);

    assert(lambda(42) == 3 * 42);

    {
        import std.concurrency;

        static void task() @safe {
            const result = 2 * assumeTrusted!(receiveOnly!int);
            assumeTrusted!({ ownerTid.send(result); });
            alias trusted_owner = assumeTrusted!(ownerTid);
            alias trusted_send = assumeTrusted!(send!(string));
            trusted_send(trusted_owner, "Hello");
        }

        auto tid = assumeTrusted!({ return spawn(&task); });
        assumeTrusted!({ send(tid, 21); });
        assert(assumeTrusted!(receiveOnly!(const(int))) == 21 * 2);
        assert(assumeTrusted!(receiveOnly!(string)) == "Hello");
    }
}

protected template _staticSearchIndexOf(int index, alias find, L...) {
    import std.meta : staticIndexOf;

    static if (isType!find) {
        enum _staticSearchIndexOf = staticIndexOf!(find, L);
    }
    else {
        static if (L.length is index) {
            enum _staticSearchIndexOf = -1;
        }
        else {
            enum found = find!(L[index]);
            static if (found) {
                enum _staticSearchIndexOf = index;
            }
            else {
                enum _staticSearchIndexOf = _staticSearchIndexOf!(index + 1, find, L);
            }
        }
    }
}

/**
This template finds the index of find in the AliasSeq L.
If find is a type it works the same as traits.staticIndexOf,
 but if func is a templeate function it will use this function as a filter
Returns:
First index where find has been found
If nothing has been found the template returns -1
 */

template staticSearchIndexOf(alias find, L...) {
    enum staticSearchIndexOf = _staticSearchIndexOf!(0, find, L);
}

static unittest {
    import std.traits : isFloatingPoint, isIntegral;

    alias seq = AliasSeq!(string, int, long, char);
    static assert(staticSearchIndexOf!(long, seq) is 2);
    static assert(staticSearchIndexOf!(isIntegral, seq) is 1);
    static assert(staticSearchIndexOf!(isFloatingPoint, seq) is -1);
}

enum unitdata = "unitdata";

/**
* Used in unitttest local the path package/unitdata/filename 
* Params:
*   filename = name of the unitdata file
*   file = defailt location of the module
* Returns:
*   unittest data filename
 */
string unitfile(string filename, string file = __FILE__) @safe {
    import std.path;

    return buildPath(file.dirName, unitdata, filename);
}

/** 
 * Mangle of a callable symbol
 * Params:
 *   T = callable symbol 
 * Returns:
 *   mangle of callable T
 */
template mangleFunc(alias T) if (isCallable!T) {
    import core.demangle : mangle;

    alias mangleFunc = mangle!(FunctionTypeOf!(T));
}

bool isinit(T)(T x) pure nothrow @safe {
    return x is T.init;
}

@safe
unittest {
    class C {
    }

    C c;
    assert(c.isinit);
    c = new C;
    assert(!c.isinit);
    static struct S {
        int x;
    }

    S s;
    assert(s.isinit);
    s = S(42);
    assert(!s.isinit);
}

auto trusted(alias func, Args...)(auto ref Args args) @trusted {
    return func(args);
}

auto scopedTrusted(alias func, Args...)(auto ref scope Args args) @trusted {
    return func(args);
}

@safe
unittest {
    import std.traits;

    @system
    int mul(int a, int b) {
        return a * b;
    }

    static assert(!isSafe!mul);
    assert(trusted!mul(1, 2) == 2);
    assert(scopedTrusted!mul(1, 2) == 2);
}
