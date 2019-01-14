module tagion.utils.CheckBSON;

import tagion.utils.BSON : Type, BinarySubType, BSON, HBSON;

import std.stdio;

@safe
struct CheckBSON(bool hbson_flag) {
    private size_t pos;
    private const(ubyte[]) data;


    @trusted
    T get_value(T)(const(ubyte[]) value) {
        pos+=T.sizeof;
        return *(cast(T*)(value.ptr));
    }

    bool check_cstring(const(ubyte[]) cstring, out size_t cpos) {
        foreach(i, c; cstring) {
            if ( c == '\0' ) {
                cpos=i;
                return true;
            }
        }
        return false;
    }

    bool check_string(const(ubyte[]) str, out size_t cpos) {
        auto str_len=get_value!uint(str);
        bool result=(str[str_len] == '\0');
        if ( result ) {
            auto cstr=str[str_len..$];
            foreach(c; str[0..str_len]) {
                if (c == '\0') {
                    result=false;
                    break;
                }
            }
        }
        cpos=uint.sizeof+str_len+1;
        return result;
    }

    bool check_e_list(const(ubyte[]) e_list, out size_t cpos) {
        auto e_list_len=get_value!uint(e_list);
        cpos=uint.sizeof;
        bool crawl(const(ubyte[]) e_list) {
            bool result=true;
            if ( e_list[0] != 0 ) {
                size_t size;
                result=check_element(e_list, size);
                cpos+=size;
                if ( result) {
                    result=crawl(e_list[size..$]);
                }
            }
            return result;
        }
        return crawl(e_list[cpos..$]);
    }

    bool check_document(const(ubyte[]) doc, out size_t cpos) {
        auto doc_len=get_value!uint(doc);
        cpos=uint.sizeof;
        size_t size;
        bool result=doc.length > 4;
        if ( result ) {
            result=check_e_list(doc[cpos..$], size);
        }
        if ( result ) {
            cpos+=size+1;
        }
        return result;
    }

    bool check_document_array(const(ubyte[]) doc_array, out size_t cpos) {
        auto doc_array_len=get_value!uint(doc_array);
        cpos=uint.sizeof;
        size_t size;
        bool result;
        while (doc_array[cpos]) {
            size_t doc_size;
            result=check_document(doc_array[cpos..doc_array_len], doc_size);
            if ( !result ) {
                break;
            }
            cpos+=doc_size;
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

    bool check_element(const(ubyte[]) full_elm, out size_t cpos) {
        byte type=full_elm[0];
        cpos=1;
        pos++;
        size_t size;
        bool result=check_cstring(full_elm[cpos..$], size);
        cpos+=size;
        auto elm=full_elm[size..$];
        if ( result ) {
            with(Type) switch (type) {
                case DOUBLE:
                    size=double.sizeof;
                    result=true;
                    break;
                case STRING:
                    result=check_string(elm, size);
                    break;
                case DOCUMENT:
                    result=check_document(data, size);
                    break;
                case ARRAY:
                    static if ( !hbson_flag ) {
                        result=check_document(data[uint.sizeof..$], size);
                    }
                    break;
                case BINARY:
                    result=check_binary(data[uint.sizeof..$], size);
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
                        result=check_cstring(data, cpos);
                        size=cpos;
                        if ( result ) {
                            result=check_cstring(data, cpos);
                            size+=pos;
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
            pos+=cpos;
        }
        return result;
    }

    this(const(ubyte[]) data) {
        this.data=data;
    }


    bool check() {
        size_t pos;
        return check_document(data, pos);
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
    {
        auto b=new HBSON();
        b["a"]="apples";
        assert(isBSONFormat(b.serialize));
        assert(isHBSONFormat(b.serialize));
        ubyte[] test=[2,3];
        writefln("%s", isBSONFormat(test));
        assert(!isBSONFormat(test));
    }
    // Type check
    version(none)
    {
        auto b=new HBSON;
        b["double"]=1.1;
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

}
