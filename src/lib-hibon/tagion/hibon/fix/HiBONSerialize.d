module tagion.hibon.fix.HiBONSerialize;

import tagion.basic.Types : Buffer;
import tagion.hibon.fix.Document;
import tagion.hibon.HiBONBase;
import std.traits;
import std.format;
import std.range;
import std.algorithm;
import LEB128 = tagion.utils.LEB128;

@safe:
enum STUB = HiBONPrefix.HASH ~ "";
bool isStub(const Document doc) pure {
    return !doc.empty && doc.keys.front == STUB;
}

enum HiBONPrefix {
    HASH = '#',
    PARAM = '$',
}

enum TYPENAME = HiBONPrefix.PARAM ~ "@";

/** 
 * Gets the doc[TYPENAME] from the document.
 * Params:
 *   doc = Document containing typename
 * Returns: TYPENAME or string.init
 */
string getType(const Document doc) pure {
    if (doc.hasMember(TYPENAME)) {
        return doc[TYPENAME].get!string;
    }
    return string.init;
}

template isHiBONArray(T) {
    import tagion.hibon.HiBONBase;
    import traits = std.traits;
    import tagion.hibon.fix.HiBONRecord : isHiBONRecord;
    import std.traits;

    alias BaseT = TypedefBase!T;
    static if (traits.isArray!BaseT) {
        alias ElementBaseT = TypedefBase!(ForeachType!(BaseT));
        enum isHiBONArray = (Document.Value.hasType!(ElementBaseT) || isHiBONRecord!ElementBaseT);
        pragma(msg, "isHiBONArray! ", T, " ", isHiBONArray, " ElementBaseT ", ElementBaseT);
    }
    else {
        enum isHiBONArray = false;
    }
}

enum estimate_size = "estimate_size"; /// method to estimae the size of document serialized 
template isHiBONAssociativeArray(T) {
    import tagion.hibon.HiBONBase;
    import traits = std.traits;
    import tagion.hibon.fix.HiBONRecord : isHiBONRecord;
    import std.traits;

    alias BaseT = TypedefBase!T;
    static if (traits.isAssociativeArray!BaseT) {
        alias ElementBaseT = TypedefBase!(ForeachType!(BaseT));
        enum isHiBONAssociativeArray = (Document.Value.hasType!(ElementBaseT) || isHiBONRecord!ElementBaseT);
        //pragma(msg, "isHiBONArray! ", T, " ", isHiBONArray, " ElementBaseT ", ElementBaseT);
    }
    else {
        enum isHiBONAssociativeArray = false;
    }
}

template SupportingFullSizeFunction(T, size_t i = 0, bool _print = false) {
    import tagion.hibon.fix.HiBONRecord : exclude, optional, isHiBONRecord;
    import std.traits;

    template InnerSupportFullSize(U) {
        import tagion.hibon.fix.HiBONRecord : exclude, optional, isHiBONRecord;
        import tagion.hibon.HiBONBase : isHiBONBaseType;

        enum type = Document.Value.asType!U;
        static if (isHiBONBaseType(type)) {
            static if (_print)
                pragma(msg, "isHiBONBaseType ", type, " U ", U);
            enum InnerSupportFullSize = true;
        }
        else static if (isHiBONRecord!U) {
            static if (_print)
                pragma(msg, "isHiBONRecord ", type, " U ", U);
            enum InnerSupportFullSize = SupportingFullSizeFunction!(U);
            //enum InnerSupportFullSize = false;
        }
        else static if (isAssociativeArray!U) { // && isSpecialKeyType!U) {
            //            enum InnerSupportFullSize=false;
            static if (_print)
                pragma(msg, "isHiBONAssociativeArray ", type, " U ", U);

            alias KeyT = KeyType!U;
            enum InnerSupportFullSize = isIntegral!KeyT || is(KeyT : const(char[]));

        }
        else {
            static if (_print)
                pragma(msg, "InnerSupportFullSize ", type, " U ", U, " ---- isHiBONArray (", isHiBONArray!U, ")");
            enum InnerSupportFullSize = isHiBONArray!U ||
                isIntegral!U;
        }
    }

    static if (i == T.tupleof.length) {
        enum SupportingFullSizeFunction = true;
    }
    else {
        enum optional_flag = hasUDA!(T.tupleof[i], optional);
        enum exclude_flag = hasUDA!(T.tupleof[i], exclude);
        static if (exclude_flag || !InnerSupportFullSize!(Fields!T[i])) {
            enum SupportingFullSizeFunction = false;
        }
    else {
            enum SupportingFullSizeFunction = SupportingFullSizeFunction!(T, i + 1);

        }
    }

}

import tagion.basic.Debug;

size_t full_size(T)(const T x) pure nothrow if (SupportingFullSizeFunction!T) {
    import std.functional : unaryFun;
    import tagion.hibon.fix.HiBONRecord : exclude, optional, filter, isHiBONRecord, GetLabel, recordType, isSpecialKeyType;
    import tagion.hibon.HiBONBase : HiBONType = Type;

    static size_t calcSize(U)(U x, const size_t key_size) {
        __write("key_size=%d U=%s", key_size, x);
        enum error_text = format("%s not supported", T.stringof);
        alias BaseT = TypedefBase!U;
        enum type = Document.Value.asType!BaseT;
        const type_key_size = key_size;
        with (Type) {
        TypeCase:
            switch (type) {
                static foreach (E; EnumMembers!Type) {
            case E:
                    static if (isHiBONBaseType(E)) {
                        static if (only(INT32, INT64, UINT32, UINT64).canFind(type)) {
                            return type_key_size + LEB128.calc_size(cast(BaseT) x);
                        }
                        else static if (type == TIME) {
                            return type_key_size + LEB128.calc_size(cast(ulong) x);
                        }
                        else static if (only(FLOAT32, FLOAT64, BOOLEAN).canFind(type)) {
                            __write("%s type_key_size=%d U.sizeof=%d %d", E, type_key_size, U.sizeof, type_key_size + U
                                    .sizeof);
                            return type_key_size + U.sizeof;
                        }
                        else static if (only(STRING, BINARY).canFind(type)) {
                            return type_key_size + LEB128.calc_size(x.length) + x.length;
                        }
                        else static if (type == BIGINT) {
                            return type_key_size + x.calc_size;
                        }
                        else static if (type == DOCUMENT) {
                            return type_key_size + x.full_size;
                        }
                        else static if (type == VER) {
                            return Type.sizeof + LEB128.calc_size(x);
                        }
                    }
                    goto default;
                }
            default:
                static if (!isHiBONBaseType(type)) {
                    static if (isHiBONArray!BaseT) {
                        import std.algorithm : filter;

                        foreach (i, v; x) {
                            __write("### %d %s size=%d", i, v, calcSize(v, Document.sizeKey(i)));
                        }
                        const array_size = x.enumerate
                            .filter!(pair => pair.value !is pair.value.init)
                            .map!(pair => calcSize(pair.value, Document.sizeKey(pair.index)))
                            .sum;
                        __write("array_size =%d leb128=%d type_key_size=%d", array_size, LEB128.calc_size(array_size), type_key_size);
                        return type_key_size + array_size + LEB128.calc_size(array_size);
                    }
                    else static if (isHiBONAssociativeArray!BaseT && !isSpecialKeyType!BaseT) {
                        import std.algorithm : filter;

                        const array_size = x.byKeyValue
                            .filter!(pair => pair.value !is pair.value.init)
                            .map!(pair => calcSize(pair.value, Document.sizeKey(pair.key)))
                            .sum;
                        return array_size + LEB128.calc_size(array_size);

                        pragma(msg, "isHiBONAssociativeArray ", BaseT, " ", typeof(x.byKeyValue.front));
                    }
                    else static if (isHiBONRecord!BaseT) {
                        return type_key_size + x.full_size;
                        pragma(msg, "HiBONRecord ", BaseT.stringof);
                    }
                    else static if (isIntegral!BaseT) {
                        static if (isSigned!BaseT) {
                            return calcSize(cast(int) x, key_size);
                        }
                        else {
                            return calcSize(cast(uint) x, key_size);
                        }

                    }
                    else static if (isInputRange!(Unqual!BaseT)) {
                        pragma(msg, "inputRange ", BaseT);
                    }
                    else {
                        pragma(msg, "!! ", SupportingFullSizeFunction!T, " isSpecialKeyType ", isSpecialKeyType!T);
                        static assert(0, format("%s not supported -- %s %s -> %s %s  is range %s", type, T
                                .stringof, BaseT
                                .stringof, [
                                    EnumMembers!HiBONType
                                ], only(STRING, BINARY)
                                .canFind(type), isInputRange!(Unqual!BaseT)));
                    }
                }
                else {
                }
            }
        }

        return 0;

    }

    size_t result;
    static if (hasUDA!(T, recordType)) {
        enum record = getUDAs!(T, recordType)[0];
        __write("TYPENAME=%s", TYPENAME);
        result += calcSize(record.name, Document.sizeKey(TYPENAME));
    }
    static foreach (i; 0 .. T.tupleof.length) {
        {

            enum optional_flag = hasUDA!(T.tupleof[i], optional);
            enum exclude_flag = hasUDA!(T.tupleof[i], exclude);
            enum filter_flag = hasUDA!(T.tupleof[i], filter);
            static if (!exclude_flag) {
                enum label = GetLabel!(T.tupleof[i]);
                //__write("lable = %s", label.name);
                const key_size = Document.sizeKey(label.name);
                __write("label=%s key_size=%d", label.name, key_size);
                version (none) static if (T.tupleof[i].sizeof == 2) {
                    pragma(msg, "With short ", ThisType);
                }
                bool include_size = true;
                static if (filter_flag) {
                    alias filters = getUDAs!(T.tupleof[i], filter);
                    static foreach (F; filters) {
                        {
                            alias filterFun = unaryFun!(F.code);
                            if (include_size && !filterFun(x.tupleof[i])) {
                                include_size = false;
                            }
                        }
                    }
                }
                if (include_size) {
                    result += calcSize(x.tupleof[i], key_size);
                    __write("result=%d", result);
                }
            }
        }
    }

    __write("before final=%d", result);
    result += LEB128.calc_size(result);
    return result;
}

        void buf_append(U)(ref scope Appender!(ubyte[]) buf, in U x, string key) pure nothrow {
        alias BaseT = TypedefBase!U;
        enum type = Document.Value.asType!BaseT;
             

        }
mixin template Serialize() {
    import std.algorithm;
    import std.range;
    import std.traits;
    import tagion.basic.Types;
    import tagion.basic.basic : isinit;

    //import tagion.hibon.HiBONBase;
    import tagion.hibon.HiBONBase : HiBONType = Type, isHiBONBaseType, is_index;
    import tagion.hibon.fix.HiBONSerialize : isHiBONAssociativeArray;
    import tagion.basic.Debug;
    import traits = std.traits;
    import std.array;

    //    static bool supportingFullSize() @nogc pure nothrow { 
    //   return SupportingFullSizeFunction!(ThisType);
    //}

    void _serialize(scope Appender!(ubyte[]) buf) const pure nothrow {
        import std.algorithm;
        import tagion.hibon.HiBONRecord : filter;


        static if (hasMember!(ThisType, estimate_size)) {
            const need_size = buf.length + estimate_size;
            if (need_size > buf.capacity) {
                buf.reserve(need_size);
            }
        }
    MemberLoop:
        static foreach (key; ThisType.keys) {
            {
                enum index = GetKeyIndex!key;
                enum exclude_flag = hasUDA!(ThisType.tupleof[index], exclude);
                enum filter_flag = hasUDA!(ThisType.tupleof[index], filter);
                static if (filter_flag) {
                    alias filters = getUDAs!(this.tupleof[index], filter);
                    static foreach (F; filters) {
                        {
                            alias filterFun = unaryFun!(F.code);
                            if (!filterFun(this.tupleof[index])) {
                                continue MemberLoop;
                            }
                        }
                    }
                }
                static if (!exclude_flag) {

                    buf_append(buf, this.tupleof[index], key);
                }
            }
        }
    }

    Buffer _serialize() const pure nothrow {
        import std.exception : assumeUnique;

        Appender!(ubyte[]) buf;
        static if (SupportingFullSizeFunction!(ThisType)) {
            const reserve_size = full_size(this);
            buf.reserve(reserve_size);
        }
        _serialize(buf);

        return (() @trusted => assumeUnique(buf.data))();
    }
}
