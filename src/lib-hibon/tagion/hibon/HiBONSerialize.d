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
            enum Ok = isKey!KeyT;
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

/**
 * Calculates the full_size of the if T support the size calculation 
 * Params:
 *   x = HiBON data type 
 * Returns: 
 *   size in bytes 
*/
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
            switch (type) {
                static foreach (E; EnumMembers!Type) {
            case E:
                    static if (isHiBONBaseType(E)) {
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
                    else static if (isAssociativeArray!BaseU) {
                        alias ValueT = ValueType!BaseU;
                        alias KeyT = KeyType!BaseU;
                        import std.algorithm : filter;

                        static if (isKey!KeyT) {
                            const array_size = x.byKeyValue
                                .filter!(pair => pair.value !is pair.value.init)
                                .map!(pair => calcSize(pair.value, Document.sizeKey(pair.key)))
                                .sum;
                            return type_key_size + array_size + LEB128.calc_size(array_size);
                        }
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
                        static assert(0, format("%s isInputRange not supported", BaseU.stringof, isInputRange.stringof));
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

mixin template Serialize() {
    import std.algorithm;
    import std.range;
    import std.traits;
    import tagion.basic.Types;
    import tagion.basic.basic : isinit;

    import tagion.hibon.HiBONBase : HiBONType = Type, isHiBONBaseType, is_index, emplace_buffer, build;
    import tagion.basic.Debug;
    import traits = std.traits;
    import std.array;
    import LEB128 = tagion.utils.LEB128;

    static if (!isSerializeDisabled!This) {
        void serialize(ref scope Appender!(ubyte[]) buf) const pure @safe {
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
                static if (index < 0) {
                    static assert(key == TYPENAME, format("RecordType %s expected", TYPENAME));
                    enum record = getUDAs!(This, recordType)[0];
                    build(buf, TYPENAME, record.name);
                }
                else {
                    enum exclude_flag = hasUDA!(This.tupleof[index], exclude);
                    enum filter_flag = hasUDA!(This.tupleof[index], filter);
                    enum preserve_flag = hasUDA!(This.tupleof[index], preserve);
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
                    static if (preserve_flag) {
                        alias MemberT = Fields!This[index];
                        alias BaseT = TypedefType!MemberT;
                        static assert(isArray!BaseT,
                                format("@%s UDA can only be apply to an array not a %s",
                                preserve.stringof, MemberT.stringof));
                    }
                    static if (!exclude_flag) {
                        build!preserve_flag(buf, key, this.tupleof[index]);
                    }
                }
            }

            static foreach (key; This.keys) {
                append_member!key();
            }
        }

        Buffer serialize() const pure @safe
        out (ret) {
            version (TOHIBON_SERIALIZE_CHECK) {
                const hibon_serialize = this.toHiBON.serialize;
                assert(ret == hibon_serialize, moduleName!This ~ "." ~ This.stringof ~ " toHiBON.serialize failed");
            }
        }
        do {
            Appender!(ubyte[]) buf;
            static if (SupportingFullSizeFunction!(This)) {
                const reserve_size = full_size(this);
                buf.reserve(reserve_size);
            }
            const start_index = buf.data.length;
            serialize(buf);
            emplace_buffer(buf, start_index);
            return buf.data;
        }
    }
}
