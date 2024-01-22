module tagion.hibon.HiBONSerialize;

import tagion.basic.Types : Buffer;
import tagion.hibon.Document;
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
    import tagion.hibon.HiBONRecord : isHiBONRecord;
    import std.traits;

    alias BaseT = TypedefBase!T;
    static if (traits.isArray!BaseT) {
        alias ElementBaseT = TypedefBase!(ForeachType!(BaseT));
        enum isHiBONArray = (Document.Value.hasType!(ElementBaseT) || isHiBONRecord!ElementBaseT);
    }
    else {
        enum isHiBONArray = false;
    }
}

//enum estimate_size = "estimate_size"; /// method to estimae the size of document serialized 
template isHiBONAssociativeArray(T) {
    import tagion.hibon.HiBONBase;
    import traits = std.traits;
    import tagion.hibon.HiBONRecord : isHiBONRecord;
    import std.traits;

    alias BaseT = TypedefBase!T;
    static if (traits.isAssociativeArray!BaseT) {
        alias ElementBaseT = TypedefBase!(ForeachType!(BaseT));
        enum isHiBONAssociativeArray = (Document.Value.hasType!(ElementBaseT) || isHiBONRecord!ElementBaseT);
    }
    else {
        enum isHiBONAssociativeArray = false;
    }
}

template SupportingFullSizeFunction(T, size_t i = 0, bool _print = false) {
    import tagion.hibon.HiBONRecord : exclude, optional, isHiBONRecord;
    import std.traits;

    template InnerSupportFullSize(U) {
        import tagion.hibon.HiBONRecord : exclude, optional, isHiBONRecord;
        import tagion.hibon.HiBONBase : isHiBONBaseType;

        alias BaseU = TypedefBase!U;
        enum type = Document.Value.asType!BaseU;
        static if (isHiBONBaseType(type)) {
            enum InnerSupportFullSize = true;
        }
        else static if (isHiBONRecord!U) {
            enum InnerSupportFullSize = SupportingFullSizeFunction!U;
        }
        else static if (isAssociativeArray!U) {
            alias KeyT = KeyType!U;
            enum Ok = isIntegral!KeyT || is(KeyT : const(char[]));
            enum InnerSupportFullSize = Ok;

        }
        else {
            enum InnerSupportFullSize = isHiBONArray!BaseU ||
                isIntegral!BaseU;
        }
    }

    alias BaseT = Unqual!T;
    static if (i == T.tupleof.length) {
        enum SupportingFullSizeFunction = true;
    }
    else {
        //enum optional_flag = hasUDA!(T.tupleof[i], optional);
        enum exclude_flag = hasUDA!(T.tupleof[i], exclude);
        static if (exclude_flag) {
            enum SupportingFullSizeFunction = SupportingFullSizeFunction!(T, i + 1, _print);
        }
        else {
            enum SupportingFullSizeFunction = InnerSupportFullSize!(Fields!T[i]) && SupportingFullSizeFunction!(T, i + 1, _print);

        }
    }

}

import tagion.basic.Debug;

size_t full_size(T)(const T x) pure nothrow if (SupportingFullSizeFunction!T) {
    import std.functional : unaryFun;
    import tagion.hibon.HiBONRecord : exclude, optional, filter, isHiBONRecord, GetLabel, recordType, isSpecialKeyType;
    import tagion.hibon.HiBONBase : HiBONType = Type;

    static size_t calcSize(U)(U x, const size_t key_size) {
        enum error_text = format("%s not supported", T.stringof);
        alias BaseU = TypedefBase!U;
        enum type = Document.Value.asType!BaseU;
        const type_key_size = key_size;
        with (Type) {
        TypeCase:
            switch (type) {
                static foreach (E; EnumMembers!Type) {
            case E:
                    static if (isHiBONBaseType(E)) {
                        //   pragma(msg, "E ", E, " U ", BaseU, " isHiBONBaseType!E ", isHiBONBaseType(E));
                        //  return element_size(x, key_size);
                        static if (only(INT32, INT64, UINT32, UINT64).canFind(type)) {
                            return type_key_size + LEB128.calc_size(cast(BaseU) x);
                        }
                        else static if (type == TIME) {
                            return type_key_size + LEB128.calc_size(cast(ulong) x);
                        }
                        else static if (only(FLOAT32, FLOAT64, BOOLEAN).canFind(type)) {
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
                    static if (isHiBONArray!BaseU) {
                        import std.algorithm : filter;

                        const array_size = x.enumerate
                            .filter!(pair => pair.value !is pair.value.init)
                            .map!(pair => calcSize(pair.value, Document.sizeKey(pair.index)))
                            .sum;
                        return type_key_size + array_size + LEB128.calc_size(array_size);
                    }
                    else static if (isHiBONAssociativeArray!BaseU && !isSpecialKeyType!BaseU) {
                        import std.algorithm : filter;

                        const array_size = x.byKeyValue
                            .filter!(pair => pair.value !is pair.value.init)
                            .map!(pair => calcSize(pair.value, Document.sizeKey(pair.key)))
                            .sum;
                        return array_size + LEB128.calc_size(array_size);

                    }
                    else static if (isHiBONRecord!BaseU) {
                        return type_key_size + x.full_size;
                    }
                    else static if (isIntegral!BaseU) {
                        static if (isSigned!BaseU) {
                            return calcSize(cast(int) x, key_size);
                        }
                        else {
                            return calcSize(cast(uint) x, key_size);
                        }

                    }
                    else static if (isInputRange!(Unqual!BaseU)) {
                        pragma(msg, "inputRange ", BaseU);
                    }
                    else {
                        static assert(0, format("%s not supported -- %s %s -> %s %s  is range %s", type,
                                T.stringof,
                                BaseU.stringof, [
                                    EnumMembers!HiBONType
                                ], only(STRING, BINARY)
                                .canFind(type), isInputRange!(Unqual!BaseU)));
                    }
                }
                //else static if (__traits(compiles, BaseT, "_serialize"
                else {
                    assert(0, format("%s HiBONType=%s not supported by %s Type=%s", T.stringof, type, __FUNCTION__, isHiBONBaseType(
                            type)));
                }
            }
        }

        return 0;

    }

    size_t result;
    static if (hasUDA!(T, recordType)) {
        enum record = getUDAs!(T, recordType)[0];
        result += calcSize(record.name, Document.sizeKey(TYPENAME));
    }
    static foreach (i; 0 .. T.tupleof.length) {
        {

            enum exclude_flag = hasUDA!(T.tupleof[i], exclude);
            enum filter_flag = hasUDA!(T.tupleof[i], filter);
            static if (!exclude_flag) {
                enum label = GetLabel!(T.tupleof[i]);
                //__write("lable = %s", label.name);
                const key_size = Document.sizeKey(label.name);
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
                }
            }
        }
    }

    result += LEB128.calc_size(result);
    return result;
}

void buf_append(U, Key)(ref scope AppendBuffer buf, in U x, Key key) pure {
    import tagion.hibon.HiBONRecord : isHiBONRecord;

    alias BaseT = TypedefBase!U;
    enum type = Document.Value.asType!BaseT;

    __write("%s key=%s type=%s", __FUNCTION__, key, type);
    build(buf, key, x);
}

mixin template Serialize() {
    import std.algorithm;
    import std.range;
    import std.traits;
    import tagion.basic.Types;
    import tagion.basic.basic : isinit;

    //import tagion.hibon.HiBONBase;
    import tagion.hibon.HiBONBase : HiBONType = Type, isHiBONBaseType, is_index, emplace_buffer;
    import tagion.hibon.HiBONSerialize : isHiBONAssociativeArray;
    import tagion.basic.Debug;
    import traits = std.traits;
    import std.array;
    import LEB128 = tagion.utils.LEB128;

    ///    static if (SupportingFullSizeFunction!This) {
    static if (__traits(hasMember, This, "enable_serialize")) {
        void _serialize(ref scope Appender!(ubyte[]) buf) const pure {
            import std.algorithm;
            import tagion.hibon.HiBONRecord : filter;

            static if (hasMember!(This, "estimate_size")) {
                const need_size = buf.data.length + this.estimate_size;
                if (need_size > buf.capacity) {
                    buf.reserve(need_size);
                }
            }
            void append_member(string key)() pure {
                enum index = GetTupleIndex!key;
                enum exclude_flag = hasUDA!(This.tupleof[index], exclude);
                enum filter_flag = hasUDA!(This.tupleof[index], filter);
                __write("key=%s index=%d exclude_flag=%s filter_flag=%s", key, index, exclude_flag, filter_flag);
                static if (filter_flag) {
                    alias filters = getUDAs!(this.tupleof[index], filter);
                    static foreach (F; filters) {
                        {
                            alias filterFun = unaryFun!(F.code);
                            if (!filterFun(this.tupleof[index])) {
                                return;
                            }
                        }
                    }
                }
                static if (!exclude_flag) {
                    buf_append(buf, this.tupleof[index], key);
                    __write("this.tupleof[index]=%s %s key=%s", this.tupleof[index], Fields!This[index].stringof, key);
                    __write("buf_append         =%s", buf.data);
                }
            }
            //version(none)
            static if (hasUDA!(This, recordType)) {
                enum record = getUDAs!(This, recordType)[0];
                buf_append(buf, record.name, TYPENAME);
            }

            static foreach (key; This.keys) {
                append_member!key();
            }
        }

        Buffer _serialize() const pure {
            Appender!(ubyte[]) buf;
            static if (SupportingFullSizeFunction!(This)) {
                const reserve_size = full_size(this);
                buf.reserve(reserve_size);
                __write("reserve_size=%d", reserve_size);
            }
            const start_index = buf.data.length;
            _serialize(buf);
            const size_leb128 = LEB128.encode(start_index);
           // buf ~= size_leb128;
            auto data = buf.data;
            __write("_serialize buf before clean buffer_size=%d ",  start_index);
           emplace_buffer(buf, start_index); 
    /*            
(() @trusted {
                import core.stdc.string : memcpy;

                memcpy(&data[size_leb128.length], &data[0], buffer_size);
                memcpy(&data[0], &size_leb128[0], size_leb128.length);
            })();
    */
            //__write("size_leb128.length=%d data.length=%d", size_leb128.length, data.length);
            //__write("data=%x buf.data=%x %d capacity=%d data.capacity=%d size_leb128=%s", &data[0], &(buf.data[0]), data
             //   .length, buf.capacity, data.capacity, size_leb128);
            __write("_serialize %s", buf.data);
            return buf.data;
        }
    }
}
