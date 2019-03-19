module tagion.utils.CheckBSON;

import tagion.utils.BSON : Type, BinarySubType, BSON, HBSON;

import std.stdio;
import tagion.Base : Check;

@safe
class CheckBSONException : Exception {

    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

alias check=Check!CheckBSONException;


@safe
struct CheckBSON(bool hbson_flag) {
    //  private size_t pos;
    const(ubyte[]) data;
    protected const(ubyte)[] current;

    @disable this();

    @trusted
    T get_value(T)(const(ubyte[]) value) {
//        pos+=T.sizeof;
        return *(cast(T*)(value.ptr));
    }

    bool check_cstring(const(ubyte[]) cstring, out size_t cpos) {
        writefln("cstring=%s", cstring);
        foreach(i, c; cstring) {
            writefln("i=%d c=%d:%s",i,c,cast(char)c);
            if ( c == '\0' ) {
                cpos=i;
                return true;
            }
        }
        return false;
    }

    bool check_string(const(ubyte[]) str, out size_t cpos) {
        current=str;
        auto str_len=get_value!uint(str);
        cpos=uint.sizeof+str_len;
        bool result=(str[cpos-1] == '\0');
        writefln("str_len=%d result=%s %d", str_len, result, str[cpos-1]);
//        cpos++;
        version(result)
        if ( result ) {
            auto cstr=str[str_len..$];
            foreach(c; str[0..str_len]) {
                if (c == '\0') {
                    result=false;
                    break;
                }
            }
        }

        return result;
    }

    bool check_e_list(const(ubyte[]) e_list) {
        writefln("e_list.lenght=%d e_list[0]=%d list=%s", e_list.length, e_list[0], e_list);
        if ( e_list[0] !=  0 ) {
//        current=e_list;
//        auto e_list_len=get_value!uint(e_list);
        writefln("e_list=%s", e_list);
        size_t size;
        return check_element(e_list, size) && check_e_list(e_list[size..$]);
//        cpos=uint.sizeof;
//        bool crawl(const(ubyte[]) e_list) {
        // bool result=true;
        // if ( e_list[0] != 0 ) {
//         size_t size;
//         result=check_element(e_list, size);
//                 writefln("after size=%d", size);
//                 if ( result) {

// //                    cpos+=size;
//                     return crawl(e_list[size..$]);
//                 }
//             }
//             return result;
        }
        return true;

//        return crawl(e_list);
    }

    bool check_document(const(ubyte[]) doc_data, out size_t size) {
        current=doc_data;
        auto doc_len=get_value!uint(doc_data);
        writefln("doc_len=%d data=%s", doc_len, doc_data);
        bool result=data.length > uint.sizeof;
        if ( result ) {
            result=(doc_len == doc_data.length);
            if ( result ) {
                // cpos+=uint.sizeof;
                result=check_e_list(doc_data[uint.sizeof..doc_len]);
//                result=check_e_list(data, size);
            }
            // if ( result ) {
            //     cpos+=size+1;
            // }
            size=doc_len;
        }
        return result;
    }

    bool check_document_array(const(ubyte[]) doc_array, out size_t cpos) {
        auto doc_array_len=get_value!uint(doc_array);
        cpos=uint.sizeof;
        size_t size;
        bool result;
        while (doc_array[cpos]) {
//            size_t doc_size;
            result=check_document(doc_array[cpos..doc_array_len], size);
            if ( !result ) {
                break;
            }
//            cpos+=doc_size;
        }
        return result;
    }

    bool check_code_w_s(const(ubyte[]) code, out size_t cpos) {
        auto code_w_s_len=get_value!uint(code);
        size_t size;
        cpos=uint.sizeof;
        bool result=check_string(code[cpos..$], size);
        cpos+=size;
        if ( result ) {
            result=check_document(code[cpos..$], size);
        }
        return result;
    }

    bool check_binary(const(ubyte[]) bin, out size_t cpos) {
        auto binary_len=get_value!uint(bin);
        size_t size;
        cpos=uint.sizeof;
        immutable subtype=bin[cpos];
        cpos++;
        bool result;
        size_t binary_size;
        with (BinarySubType) switch(subtype) {
            case generic:
                result=true;
                break;
            case func:
                result=!hbson_flag;
                break;
            case binary:
                result=false;
                break;
            case uuid:
                result=!hbson_flag;
                break;
            case md5:
                result=!hbson_flag;
                break;
            case userDefined:
                result=!hbson_flag;
                break;
            case INT32_array:
                binary_size=int.sizeof;
                result=hbson_flag;
                break;
            case INT64_array:
                binary_size=long.sizeof;
                result=hbson_flag;
                break;
            case DOUBLE_array:
                binary_size=double.sizeof;
                result=hbson_flag;
                break;
            case UINT32_array:
                binary_size=uint.sizeof;
                result=hbson_flag;
                break;
            case UINT64_array:
                binary_size=ulong.sizeof;
                result=hbson_flag;
                break;
            case FLOAT_array:
                binary_size=float.sizeof;
                result=hbson_flag;
                break;
            default:
                result=false;
            }
        if ( result ) {
            immutable binarry_array_size=size-cpos;
            result=(binarry_array_size % binary_size == 0);
            cpos=size;
        }
        return result;
    }

    @trusted
    bool check_element(const(ubyte[]) full_elm, out size_t cpos) {
        current=full_elm;
        byte type=full_elm[0];
        cpos=ubyte.sizeof;

        writefln("type=%d full_elm[cpos..$]=%s", type, full_elm[cpos..$]);
        size_t size;
        bool result=check_cstring(full_elm[cpos..$], size);
        writefln("size=%d %s", size, cast(string)(full_elm[cpos..cpos+size]));

//        if ( result ) {
        cpos+=size+1;
        auto elm=full_elm[cpos..$];
        writefln("elm=%s", elm);
//        return true;
        if ( result ) {
            with(Type) switch (type) {
                case DOUBLE:
                    writef("type=%s %s", type, get_value!double(elm));
                    size=double.sizeof;
                    writefln("->size=%d %s", size, elm[size..$]);
                    result=true;
                    break;
                case STRING:
                    writef("type=%s ", type);
                    result=check_string(elm, size);
                    writefln("->size=%d", size);
                    break;
                case DOCUMENT:
                        result=check_document(elm, size);
                        break;
                    case ARRAY:
                        static if ( !hbson_flag ) {
                            result=check_document(elm, size);
                        }
                        break;
                    case BINARY:
                        result=check_binary(elm[uint.sizeof..$], size);
                        break;
                    case OID:
                        size=12;
                        result=true;
                        break;
                    case BOOLEAN:
                        size=1;
                        result=true;
                        break;
                    case DATE:
                        size=long.sizeof;
                        result=true;
                        break;
                    case NULL:
                        size=0;
                        result=true;
                        break;
                    case REGEX:
                        static if ( !hbson_flag ) {
                            result=check_cstring(elm, size);
                            if ( result ) {
                                result=check_cstring(elm, size);
                            }
                        }
                        break;
                    case JS_CODE:
                        static if ( !hbson_flag ) {
                            result=check_string(elm, size) ;
                        }
                        break;
                    case JS_CODE_W_SCOPE:
                        static if ( !hbson_flag ) {
                            result=check_code_w_s(elm, size);
                        }
                    break;
                    case INT32:
                        size=int.sizeof;
                        result=true;
                        break;
                    case TIMESTAMP:
                        size=long.sizeof;
                        result=true;
                        break;
                    case INT64:
                    size=long.sizeof;
                    result=true;
                    break;
                    case UINT32:
                        size=uint.sizeof;
                        result=true;
                        break;
                case UINT64:
                    size=ulong.sizeof;
                    result=true;
                    break;
                    case FLOAT:
                        size=float.sizeof;
                        result=true;
                        break;
                    default:
                        result=false;
                }
            }
            if ( result ) {
                cpos+=size;
            }
//        }
        return result;
    }

    this(const(ubyte[]) data) {
        this.data=data;
    }


    @trusted
    size_t pos() {
        return (data.ptr-current.ptr);
    }

    bool check() {
//        size_t pos;
        writeln("---- ---- ----");
        writefln("data=%s %d", data, data.length);
        size_t size;
        bool result=check_document(data, size);
        writefln("check.result=%d", size);
        return result;
    }

    // static bool opCall(const(ubyte[]) data) {
    //     auto test=CheckBSON(data);
    //     return test.check();
    // }
}


bool isBSONFormat(const(ubyte[]) data) {
    return CheckBSON!false(data).check;
}

bool isHBSONFormat(const(ubyte[]) data) {
    return CheckBSON!true(data).check;
}


//TO_DO: Make a isBSONFormat() static function.
unittest {
//    version(none)
    {
        auto b=new HBSON();
        immutable double x=3.1415;
        b["double"]=x;
        auto data=b.serialize;
        assert(isBSONFormat(data));
        assert(isHBSONFormat(data));
    }

    {
        auto b=new HBSON();
        b["string"]="apples";
        auto data=b.serialize;
        assert(isBSONFormat(data));
        assert(isHBSONFormat(data));
    }
    // Type check
    {
        auto b=new HBSON;
        b["string1"]="text1";
        b["text2"]="string2";
//        b["s"]="string";

//        b["double"]=1.1;
//        b["double"]=1;
        auto data=b.serialize;
        writefln("%s", isBSONFormat(data));
        writefln("%s", isHBSONFormat(data));
    }
    version(none)
    {
        assert(isBSONFormat(b.serialize));
        assert(isHBSONFormat(b.serialize));
        b["string"]="string";
        assert(isBSONFormat(b.serialize));
        assert(isHBSONFormat(b.serialize));
        ubyte[] binary=[1,2,3];
        b["binary"]=binary;
        assert(isBSONFormat(b.serialize));
        assert(isHBSONFormat(b.serialize));

    }
    writeln("End of Check BSON");
}
