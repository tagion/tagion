module tagion.hibon.HiBONSerialize;

import tagion.basic.Types : Buffer;
import tagion.hibon.Document;

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
        pragma(msg, "isHiBONArray! ", T, " ", isHiBONArray, " ElementBaseT ", ElementBaseT);
    }
    else {
        enum isHiBONArray = false;
    }
}

template isHiBONAssociativeArray(T) {
    import tagion.hibon.HiBONBase;
    import traits = std.traits;
    import tagion.hibon.HiBONRecord : isHiBONRecord;
    import std.traits;

    alias BaseT = TypedefBase!T;
    static if (traits.isAssociativeArray!BaseT) {
        alias ElementBaseT = TypedefBase!(ForeachType!(BaseT));
        enum isHiBONAssociativeArray = (Document.Value.hasType!(ElementBaseT) || isHiBONRecord!ElementBaseT);
        pragma(msg, "isHiBONArray! ", T, " ", isHiBONArray, " ElementBaseT ", ElementBaseT);
    }
    else {
        enum isHiBONAssociativeArray = false;
    }
}

mixin template Serialize() {
    import std.algorithm;
    import std.range;
    import std.traits;
    import tagion.basic.Types;
    import tagion.hibon.HiBONBase;
    import tagion.hibon.HiBONBase : HiBONType = Type;
    import LEB128 = tagion.utils.LEB128;
    import tagion.basic.Debug;
    import traits = std.traits;

    static size_t keySize(string key) pure nothrow {
        version (none) {
            uint index;
            if (is_index(key, index)) {
                return LEB128.calc_size(index) + ubyte.sizeof;
            }
        }
        //return LEB128.calc_size(key.length) + key.length;

        return key.length;
    }

    size_t _full_size() const pure nothrow {
        static size_t calcSize(T)(T x, const size_t key_size) {
            enum error_text = format("%s not supported", T.stringof);
            alias BaseT = TypedefBase!T;
            enum type = Document.Value.asType!BaseT;
            const type_key_size = Type.sizeof + key_size;
            //__write("type = %s", type);
            //pragma(msg,  " type = ", type, " BaseT = ", BaseT);
            with (HiBONType) {
            TypeCase:
                switch (type) {
                    static foreach (E; EnumMembers!HiBONType) {
                case E:
                        static if (isHiBONBaseType(E)) {
                            __write("E = %s BaseT = %s key_size=%d", E, BaseT.stringof, key_size);

                            static if (only(INT32, INT64, UINT32, UINT64).canFind(type)) {
                                return type_key_size + LEB128.calc_size(cast(BaseT) x);
                            }
                            else static if (type == TIME) {
                                return type_key_size + LEB128.calc_size(cast(ulong) x);
                            }
                            else static if (only(FLOAT32, FLOAT64, BOOLEAN).canFind(type)) {
                                return type_key_size + T.sizeof;
                            }
                            else static if (only(STRING, BINARY).canFind(type)) {
                                return type_key_size + LEB128.calc_size(x.length) + x.length;
                            }
                            else static if (type == BIGINT) {
                                return type_key_size + x.calc_size;
                            }
                            else static if (type == DOCUMENT) {
                                pragma(msg, "- - -> ", type, " : ", T.stringof);
                                return type_key_size + x.full_size;
                            }
                            else static if (type == VER) {
                                return Type.sizeof + LEB128.calc_size(x);
                            }
                            else {
                                goto default;
                                //static assert(0, format("%s not supported", T.));
                            }
                        }
                        break TypeCase;
                    }
                default:
                    static if (!isHiBONBaseType(type)) {
                        //static if (traits.isArray!BaseT && (Document.Value.hasType!(ForeachType!BaseT) || isHiBONRecord!(
                        //      ForeachType!BaseT))) {
                        //}
                        static if (isHiBONArray!BaseT) {
                            pragma(msg, "isHiBONArray ", BaseT);    
                        }
                    else static if (isHiBONAssociativeArray!BaseT) {
                            pragma(msg, "isHiBONAssociativeArray ", BaseT);    
                        }
                        else static if (isHiBONRecord!BaseT) {
                            pragma(msg, "HiBONRecord ", BaseT.stringof);
                        }
                        else static if (isIntegral!BaseT) {
                            pragma(msg, "Short ", BaseT.sizeof);
                        
                        }
                        else static if (isInputRange!(Unqual!BaseT)) {
                            pragma(msg, "inputRange ", BaseT);
                        }
                        else {
                            static assert(0, format("%s not supported -- %s %s -> %s %s  is range %s", type, T.stringof, BaseT
                                    .stringof, [
                                        EnumMembers!Type
                                    ], only(STRING, BINARY).canFind(type), isInputRange!(Unqual!BaseT)));
                        }
                    }
                    else {
                    }
                }
            }

            return 0;

        }

        size_t result;
        static foreach (i; 0 .. ThisType.tupleof.length) {
            {

                enum optional_flag = hasUDA!(this.tupleof[i], optional);
                enum exclude_flag = hasUDA!(this.tupleof[i], exclude);
                static if (!exclude_flag) {
                    enum label = GetLabel!(this.tupleof[i]);
                    __write("lable = %s", label.name);
                    const key_size = keySize(label.name);
                    static if (this.tupleof[i].sizeof == 2) {
                        pragma(msg, "With short ", ThisType);
                    }
                    result += calcSize(this.tupleof[i], key_size);
                }
            }
        }

        return result;
    }

    Buffer _serialize() const pure nothrow {

        return Buffer.init;
    }
}
