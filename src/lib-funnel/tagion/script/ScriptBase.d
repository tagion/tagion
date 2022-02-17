module tagion.script.ScriptBase;

import std.stdio;

//import std.internal.math.biguintcore : BigDig;
//import std.bigint;

import std.typecons : Typedef, TypedefType;

//import std.format;
import std.meta : AliasSeq;
import std.traits : Unqual, hasUDA, getUDAs, isIntegral, isSomeString, EnumMembers;
import std.conv : emplace;

import tagion.basic.Message : message;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.Basic : isOneOf, CastTo;
import BigNumber = tagion.hibon.BigNumber;

import tagion.basic.TagionExceptions : Check, TagionException;

@safe
class ScriptException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

package alias check = Check!ScriptException;

public alias Number = BigNumber.BigNumber;

enum FunnelType {
    NONE,
    //    INTEGER,
    TEXT,
    HIBON,
    //    HIBONRANGE
    DOCUMENT,
    //    DOCRANGE,
    BINARY,
    NUMBER, //    FUNCTION
}

@safe
union Variant {
    //    @FunnelType(FunnelType.INTEGER)  long integer;
    @FunnelType(FunnelType.TEXT) string text;
    @FunnelType(FunnelType.HIBON) HiBON hibon;
    @FunnelType(FunnelType.DOCUMENT) Document document;
    @FunnelType(FunnelType.BINARY) immutable(ubyte)[] binary;
    @FunnelType(FunnelType.NUMBER) Number number;
    //  @FunnelType(FunnelType.FUNCTION) const(ScriptBasic) func;

    protected template GetFunctions(string text, bool first, TList...) {
        import std.format;

        static if (TList.length is 0) {
            enum GetFunctions = text ~ "else {\n    static assert(0, format(\"Not support illegal %s \", type )); \n}";
        }
        else {
            enum name = TList[0];
            enum member_code = "alias member=Variant." ~ name ~ ";";
            mixin(member_code);
            static if (__traits(compiles, typeof(member)) && hasUDA!(member, FunnelType)) {
                enum MemberType = getUDAs!(member, FunnelType)[0];
                alias MemberT = typeof(member);

                enum code = format("%sstatic if ( type is %s.%s ) {\n    return %s;\n}\n",
                            (first) ? "" : "else ", FunnelType.stringof, MemberType, name);
                enum GetFunctions = GetFunctions!(text ~ code, false, TList[1 .. $]);
            }
            else {
                enum GetFunctions = GetFunctions!(text, false, TList[1 .. $]);
            }
        }
    }

    @trusted
    auto by(FunnelType type)() pure inout {
        enum code = GetFunctions!("", true, __traits(allMembers, Variant));
        mixin(code);
        assert(0);
    }

    @trusted
    package auto interalBy(FunnelType type)() const pure nothrow {
        enum code = GetFunctions!("", true, __traits(allMembers, Variant));
        assert(0);
    }

    protected template GetType(T, TList...) {
        static if (TList.length is 0) {
            enum GetType = FunnelType.NONE;
        }
        else {
            enum name = TList[0];
            enum member_code = "alias member=Variant." ~ name ~ ";";
            mixin(member_code);
            static if (__traits(compiles, typeof(member)) && hasUDA!(member, FunnelType)) {
                enum MemberType = getUDAs!(member, FunnelType)[0];
                alias MemberT = typeof(member);
                static if (is(T == MemberT)) {
                    enum GetType = MemberType;
                }
                else {
                    enum GetType = GetType!(T, TList[1 .. $]);
                }
            }
            else {
                enum GetType = GetType!(T, TList[1 .. $]);
            }
        }
    }

    enum asType(T) = GetType!(Unqual!T, __traits(allMembers, Variant));
    enum hasType(T) = asType!T !is Type.NONE;

    @trusted
    this(const Document doc) {
        document = doc; // To prevent the error "field `document` must be initialized in constructor"
        //        emplace(&this, doc);
        //        emplace!Document(&doc, &this);
    }

    @trusted
    this(const Number num) {
        number = num;
        //        emplace(&this, num);
        //        emplace!Document(&doc, &this);
    }

    @trusted this(HiBON x) {
        hibon = x;
    }

    @trusted
    this(T)(T x) if (isOneOf!(Unqual!T, typeof(this.tupleof)) && !is(T == struct)) {
        import std.format;

        alias MutableT = Unqual!T;
        static foreach (m; __traits(allMembers, Variant)) {
            static if (is(typeof(__traits(getMember, this, m)) == MutableT)) {
                enum code = format("alias member=Variant.%s;", m);
                mixin(code);
                static if (hasUDA!(member, FunnelType)) {
                    alias MemberT = typeof(member);
                    static if (is(T == MemberT)) {
                        __traits(getMember, this, m) = x;
                        return;
                    }
                }
            }
        }
        assert(0, format("%s is not supported", T.stringof));
    }

    alias TypeT(FunnelType aType) = typeof(by!aType());
}

@safe
class Value {
    //    protected Variant variant;
    private Variant variant;
    immutable FunnelType type;
    // this() {
    //     this(0);
    // }
    this(T)(T param) if (isOneOf!(Unqual!T, typeof(Variant.tupleof))) {
        import std.format;

        alias UnqualT = Unqual!T;
        alias E = Variant.asType!T;
        static assert(E !is FunnelType.NONE, format("Type %s is not supported by Funnel Value", T
                .stringof));
        type = E;
        variant = Variant(param);
    }

    alias CastTypes = AliasSeq!(uint, int, ulong, long, string);

    this(T)(T param) if (!isOneOf!(Unqual!T, typeof(Variant.tupleof))) {
        import std.format;

        alias UnqualT = Unqual!T;
        alias CastT = CastTo!(UnqualT, CastTypes);
        static assert(!is(CastT == void), format("Type %s not supported", T.stringof));
        static if (isIntegral!CastT) {
            alias E = FunnelType.NUMBER;
            variant = Variant(Number(cast(CastT) param));
        }
        else static if (isSomeString!T) { // string
            alias E = FunnelType.TEXT;
            variable = Variant(param.to!string);
        }
        else {
            alias E = FunnelType.NONE;
            static assert(0, format("Type %s is not supported by Funnel Value", T.stringof));
        }
        type = E;
    }

    this(Value v) {
        type = v.type;
        variant = v.variant;
    }

    private this(const Variant variant, const FunnelType type) {
        this.type = type;
        this.variant = variant;
    }

    @trusted
    static Value opCall(T)(T param) if (!is(T : const(Value))) {
        return new Value(param);
    }

    final T get(T)() inout if (Variant.asType!(Unqual!T) !is FunnelType.NONE) {
        alias UnqualT = Unqual!T;
        enum E = Variant.asType!UnqualT;
        return by!E;
    }

    final T get(T)() if (isIntegral!T && Variant.asType!(Unqual!T) is FunnelType.NONE) {
        alias UnqualT = Unqual!T;
        enum E = Variant.asType!UnqualT;

        

        .check(type is FunnelType.NUMBER, message("Number type excepted and not %s", type));
        return variant.to!T;
    }

    final bool get(T)() if (is(T == bool)) {

        

            .check(type is FunnelType.NUMBER, message("Number type excepted and not %s", type));
        return variant.by!(FunnelType.NUMBER) != 0;
    }

    final auto by(FunnelType E)() inout {

        

            .check(type is E, message("Expected type %s but access with %s", E, type));
        return variant.by!E;
    }

    final void set(T)(T x) {
        with (FunnelType) {
        FunnelTypeCase:
            final switch (type) {
                static foreach (E; EnumMembers!FunnelType) {
            case E:
                    static if (E is NONE) {
                        enum valid_type = false;
                        assert(0, "Type should be defined");
                    }
                    else static if (E is NUMBER) {
                        enum valid_type = is(T : const(Number)) || isIntegral!T;
                    }
                    else static if (E is DOCUMENT) {
                        enum valid_type = is(T : const(Document));
                    }
                    else {
                        alias BaseT = Variant.TypeT!E;
                        enum valid_type = is(T : BaseT);
                    }

                    

                    .check(valid_type,
                            message("Type compatible with %s but %s is not", E, T.stringof));
                    variant = Variant(x);
                    break FunnelTypeCase;
                }
            }
        }
    }

    package final internalBy(FunnelType E)() const pure nothrow {
        return variant.by!E;
    }

    override string toString() const {
        return toText;
    }

    string toText() const {
        with (FunnelType) {
            final switch (type) {
                static foreach (E; EnumMembers!FunnelType) {
            case E:
                    static if (E is NUMBER) {
                        return internalBy!(E).toDecimalString;
                    }
                    else static if (E is TEXT) {
                        return internalBy!(E);
                    }
                    else static if (E is BINARY) {
                        import tagion.utils.Miscellaneous : toHex = toHexString;

                        return internalBy!(E).toHex;
                    }
                    // else static if (E is HIBON) {
                    //     return internalBy!(E)[].keys.to!string;
                    // }
                    // else static if (E is DOCUMENT) {
                    //     return internalBy!(E)[].keys.to!string;
                    // }
                    else {
                        return "{" ~ E.stringof ~ "}";
                    }
                }
            }
        }
    }
}
