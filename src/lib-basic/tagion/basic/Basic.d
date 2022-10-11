module tagion.basic.Basic;

private import std.string : format, join, strip;
private import std.traits;
private import std.exception : assumeUnique;
import std.bitmanip : BitArray;
import std.meta : AliasSeq;
import std.range.primitives : isInputRange;

enum this_dot = "this.";
import std.conv;

/++
 Returns:
 a immuatble do
+/
immutable(BUF) buf_idup(BUF)(immutable(Buffer) buffer)
{
    return cast(BUF)(buffer.idup);
}

/++
   Returns:
   The position of first '.' in string and
 +/
template find_dot(string str, size_t index = 0)
{
    static if (index >= str.length)
    {
        enum zero_index = 0;
        alias zero_index find_dot;
    }
    else static if (str[index] == '.')
    {
        enum index_plus_one = index + 1;
        static assert(index_plus_one < str.length, "Static name ends with a dot");
        alias index_plus_one find_dot;
    }
    else
    {
        alias find_dot!(str, index + 1) find_dot;
    }
}

/++
 Wraps a safe version of to!string for a BitArray
 +/
string toText(const(BitArray) bits) @trusted
{
    return bits.to!string;
}

template suffix(string name, size_t index)
{
    static if (index is 0)
    {
        alias suffix = name;
    }
    else static if (name[index - 1]!is '.')
    {
        alias suffix = suffix!(name, index - 1);
    }
    else
    {
        enum cut_name = name[index .. $];
        alias suffix = cut_name;
    }
}

/++
 Template function returns the suffux name after the last '.'
 +/
template basename(alias K)
{
    static if (is(K == string))
    {
        enum name = K;
    }
    else
    {
        enum name = K.stringof;
    }
    enum basename = suffix!(name, name.length);
}

enum nameOf(alias nameType) = __traits(identifier, nameType);

/++
 Returns:
 function name of the current function
+/
mixin template FUNCTION_NAME()
{
    import tagion.basic.Basic : basename;

    enum __FUNCTION_NAME__ = basename!(__FUNCTION__)[0 .. $ - 1];
}

unittest
{
    enum name_another = "another";
    struct Something
    {
        mixin("int " ~ name_another ~ ";");
        void check()
        {
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
template EnumText(string name, string[] list, bool first = true)
{
    static if (first)
    {
        enum begin = "enum " ~ name ~ "{";
        alias EnumText!(begin, list, false) EnumText;
    }
    else static if (list.length > 0)
    {
        enum k = list[0];
        enum code = name ~ k ~ " = " ~ '"' ~ k ~ '"' ~ ',';
        alias EnumText!(code, list[1 .. $], false) EnumText;
    }
    else
    {
        enum code = name ~ "}";
        alias code EnumText;
    }
}

///
unittest
{
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
@trusted int log2(ulong n)
{
    if (n == 0)
    {
        return -1;
    }
    import core.bitop : bsr;

    return bsr(n);
}

///
unittest
{
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
string tempfile()
{
    import std.file : deleteme;

    int dummy;
    return deleteme ~ (&dummy).to!string;
}

/++
 Returns:
 true if the type T is one of types in the list TList
+/
template isOneOf(T, TList...)
{
    static if (TList.length == 0)
    {
        enum isOneOf = false;
    }
    else static if (is(T == TList[0]))
    {
        enum isOneOf = true;
    }
    else
    {
        alias isOneOf = isOneOf!(T, TList[1 .. $]);
    }
}

///
static unittest
{
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
template CastTo(T, TList...)
{
    static if (TList.length is 0)
    {
        alias CastTo = void;
    }
    else
    {
        alias castT = TList[0];
        static if (is(T : castT))
        {
            alias CastTo = castT;
        }
        else
        {
            alias CastTo = CastTo!(T, TList[1 .. $]);
        }
    }
}

///
static unittest
{
    static assert(is(void == CastTo!(string, AliasSeq!(int, long, double))));
    static assert(is(double == CastTo!(float, AliasSeq!(int, long, double))));
    static assert(is(string == CastTo!(string, AliasSeq!(uint, string))));
    static assert(is(uint == CastTo!(ushort, AliasSeq!(uint, string))));
    static assert(is(uint == CastTo!(int, AliasSeq!(string, uint))));
    static assert(is(const(uint) == CastTo!(inout(uint), AliasSeq!(const(uint), const(string)))));
}

import std.typecons : Tuple;

alias FileNames = Tuple!(string, "tempdir", string, "filename", string, "fullpath");
const(FileNames) fileId(T)(string ext, string prefix = null) @safe
{
    import std.process : environment, thisProcessID;
    import std.file;
    import std.path;
    import std.array : join;

    //import std.traits;
    FileNames names;
    names.tempdir = tempDir.buildPath(environment.get("USER"));
    names.filename = setExtension([prefix, thisProcessID.to!string, T.stringof].join("_"), ext);
    names.fullpath = buildPath(names.tempdir, names.filename);
    names.tempdir.exists || names.tempdir.mkdir;
    return names;
}

template EnumContinuousSequency(Enum) if (is(Enum == enum))
{
    template Sequency(EList...)
    {
        static if (EList.length is 1)
        {
            enum Sequency = true;
        }
        else static if (EList[0] + 1 is EList[1])
        {
            enum Sequency = Sequency!(EList[1 .. $]);
        }
        else
        {
            enum Sequency = false;
        }
    }

    enum EnumContinuousSequency = Sequency!(EnumMembers!Enum);
}

static unittest
{
    enum Count
    {
        zero,
        one,
        two,
        three
    }

    static assert(EnumContinuousSequency!Count);

    enum NoCount
    {
        zero,
        one,
        three = 3
    }

    static assert(!EnumContinuousSequency!NoCount);

    enum OffsetCount
    {
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
template doFront(Range) if (isInputRange!Range)
{
    alias T = ForeachType!Range;
    import std.range;

    T doFront(Range r) @safe
    {
        if (r.empty)
        {
            return T.init;
        }
        return r.front;
    }
}

@safe
unittest
{
    {
        int[] a;
        static assert(isInputRange!(typeof(a)));
        assert(a.doFront is int.init);
    }
    {
        const a = [1, 2, 3];
        assert(a.doFront is a[0]);
    }
}

enum isEqual(T1, T2) = is(T1 == T2);
//enum isUnqualEqual(T1, T2) = is(Unqual!T1 == T2);

unittest
{
    import std.traits : Unqual;
    import std.meta : ApplyLeft, ApplyRight;

    static assert(isEqual!(int, int));
    static assert(!isEqual!(int, long));
    alias U = immutable(int);
    static assert(isEqual!(int, Unqual!U));
    alias Left = ApplyLeft!(isEqual, int);
    static assert(Left!(Unqual!U));
}

auto eatOne(R)(ref R r) if (isInputRange!R)
{
    import std.range;

    scope (exit)
    {
        r.popFront;
    }
    return r.front;
}

unittest
{
    const(int)[] a = [1, 2, 3];
    assert(eatOne(a) == 1);
    assert(eatOne(a) == 2);
    assert(eatOne(a) == 3);
}

/// Calling any system functions.
template assumeTrusted(alias F)
{
    import std.traits;

    static assert(isUnsafe!F);

    auto assumeTrusted(Args...)(Args args) @trusted
    {
        return F(args);
    }
}

///
@safe
unittest
{
    auto bar(int b) @system
    {
        return b + 1;
    }

    const b = assumeTrusted!bar(5);
    assert(b == 6);

    // applicable to 0-ary function
    static auto foo() @system
    {
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

        static void task() @safe
        {
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

protected template _staticSearchIndexOf(int index, alias find, L...)
{
    import std.meta : staticIndexOf;

    static if (isType!find)
    {
        enum _staticSearchIndexOf = staticIndexOf!(find, L);
    }
    else
    {
        static if (L.length is index)
        {
            enum _staticSearchIndexOf = -1;
        }
        else
        {
            enum found = find!(L[index]);
            pragma(msg, "found ", found);
            static if (found)
            {
                enum _staticSearchIndexOf = index;
            }
            else
            {
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

template staticSearchIndexOf(alias find, L...)
{
    enum staticSearchIndexOf = _staticSearchIndexOf!(0, find, L);
}

static unittest
{
    import std.traits : isIntegral, isFloatingPoint;

    alias seq = AliasSeq!(string, int, long, char);
    pragma(msg, "staticSearchIndexOf ", staticSearchIndexOf!(long, seq));
    static assert(staticSearchIndexOf!(long, seq) is 2);
    static assert(staticSearchIndexOf!(isIntegral, seq) is 1);
    static assert(staticSearchIndexOf!(isFloatingPoint, seq) is -1);
}

enum unitdata = "unitdata";
/**
   Returns:
   unittest data filename
 */
string unitfile(string filename, string file = __FILE__)
{
    import std.path;

    return buildPath(file.dirName, unitdata, filename);
}

template mangleFunc(alias T) if (isCallable!T)
{
    import core.demangle : mangle;

    alias mangleFunc = mangle!(FunctionTypeOf!(T));
}

pragma(msg, "ib: replace template with functions like sendTrusted");
@safe mixin template TrustedConcurrency()
{
    private
    {
        import concurrency = std.concurrency;
        import core.time : Duration;

        alias Tid = concurrency.Tid;

        static void send(Args...)(Tid tid, Args args) @trusted
        {
            concurrency.send(tid, args);
        }

        static void prioritySend(Args...)(Tid tid, Args args) @trusted
        {
            concurrency.prioritySend(tid, args);
        }

        static void receive(Args...)(Args args) @trusted
        {
            concurrency.receive(args);
        }

        static auto receiveOnly(T...)() @trusted
        {
            return concurrency.receiveOnly!T;
        }

        static bool receiveTimeout(T...)(Duration duration, T ops) @trusted
        {
            return concurrency.receiveTimeout!T(duration, ops);
        }

        static Tid ownerTid() @trusted
        {
            return concurrency.ownerTid;
        }

        static Tid thisTid() @safe
        {
            return concurrency.thisTid;
        }

        static Tid spawn(F, Args...)(F fn, Args args) @trusted
        {
            return concurrency.spawn(fn, args);
        }

        static Tid locate(string name) @trusted
        {
            return concurrency.locate(name);
        }

        static bool register(string name, Tid tid) @trusted
        {
            return concurrency.register(name, tid);
        }
    }
}

private import std.range;
private import tagion.basic.Types : FileExtension;

//private std.range.primitives;
string fileExtension(string path)
{
    import std.path : extension;
    import tagion.basic.Types : DOT;

    switch (path.extension)
    {
        static foreach (ext; EnumMembers!FileExtension)
        {
    case DOT ~ ext:
            return ext;
        }
    default:
        return null;
    }
    assert(0);
}

unittest
{
    import tagion.basic.Types : FileExtension;
    import std.path : setExtension;

    assert(!"somenone_invalid_file.extension".fileExtension);
    immutable valid_filename = "somenone_valid_file".setExtension(FileExtension.hibon);
    assert(valid_filename.fileExtension);
    assert(valid_filename.fileExtension == FileExtension.hibon);
}
