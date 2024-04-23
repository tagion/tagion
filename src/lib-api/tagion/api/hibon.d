/// API for using hibon
module tagion.api.hibon;
import tagion.api.errors;
import tagion.hibon.HiBON;
import core.stdc.stdint;
import tagion.hibon.Document;
import tagion.utils.StdTime;
import tagion.hibon.BigNumber;

extern(C):
version(unittest) {
} 
else {
nothrow:
}

enum MAGIC_HIBON = 0xB000_0001;
struct HiBONT {
    int magic_byte = MAGIC_HIBON;
    void* hibon;
}

/** 
 * Create new hibon object
 * Params:
 *   instance = HiBONT struct which contains magic bytes
 * Returns: ErrorCode
 */
int tagion_hibon_create(HiBONT* instance) {
    try {
        if (instance is null) {
            return ErrorCode.error;
        }
        instance.hibon =cast(void*) new HiBON;
        instance.magic_byte = MAGIC_HIBON;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}
///
unittest {
    HiBONT h;
    int rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "could not create hibon");
}

/** 
 * Insert string into hibon
 * Params:
 *   instance = the instance to insert the key value into
 *   key = pointer to the key
 *   key_len = length of the key
 *   value = pointer to the string
 *   value_len = length of the string
 * Returns: ErrorCode
 */
int tagion_hibon_add_string(const(HiBONT*) instance, 
                            const char* key, 
                            const size_t key_len, 
                            const char* value, 
                            const size_t value_len) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            return ErrorCode.exception;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0..key_len].idup;
        const _value = value[0..value_len].idup;
        h[_key] = _value;
    } 
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}
///
unittest {
    HiBONT h;
    int rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "could not create hibon");
    string key = "some_key";
    string value = "some_value";
    rt = tagion_hibon_add_string(&h, &key[0], key.length, &value[0], value.length);
    HiBON string_hibon = cast(HiBON) h.hibon;
    assert(string_hibon[key].get!string == value);
}

/** 
 * Add document to hibon
 * Params:
 *   instance = pointer to the hibon instance
 *   key = pointer to the key
 *   key_len = length of the key
 *   buf = pointer to the document buffer
 *   buf_len = length of the buffer
 * Returns: ErrorCode
 */
int tagion_hibon_add_document(const(HiBONT*) instance, 
                              const char* key, 
                              const size_t key_len, 
                              const(uint8_t*) buf, 
                              const size_t buf_len) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            return ErrorCode.exception;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0..key_len].idup;
        immutable _buf = buf[0..buf_len].idup;
        const doc = Document(_buf);
        const doc_error = doc.valid;
        if (doc_error !is Document.Element.ErrorCode.NONE) {
            return cast(int) doc_error;
        }
        h[_key] = doc;
    } catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
unittest {
    auto sub_hibon = new HiBON;
    sub_hibon["sub_doc"] = "test";
    const doc = Document(sub_hibon);

    HiBONT h;
    int rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "could not create hibon");
    string key = "some_key";

    rt = tagion_hibon_add_document(&h, &key[0], key.length, &doc.data[0], doc.data.length);
    HiBON string_hibon = cast(HiBON) h.hibon;
    assert(string_hibon[key].get!Document == doc);
}

/** 
 * Add hibon to hibon instance
 * Params:
 *   instance = pointer to the hibon instance
 *   key = pointer to the key 
 *   key_len = length of the key
 *   sub_instance = pointer to the sub hibon instance that needs to be inserted
 * Returns: ErrorCode
 */
int tagion_hibon_add_hibon(const(HiBONT*) instance, 
                           const char* key, 
                           const size_t key_len, 
                           const(HiBONT*) sub_instance) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            return ErrorCode.exception;
        }
        HiBON h = cast(HiBON) instance.hibon;
        // do the same for the subinstance
        if (sub_instance is null || sub_instance.magic_byte != MAGIC_HIBON) {
            return ErrorCode.exception;
        }
        HiBON sub_h = cast(HiBON) sub_instance.hibon;
        const _key = key[0..key_len].idup;
        h[_key] = sub_h;
    } catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/// 
unittest {
    HiBONT sub_h;
    int rt = tagion_hibon_create(&sub_h);
    assert(rt == ErrorCode.none, "could not create hibon");
    string key = "some_key";
    string value = "some_value";
    rt = tagion_hibon_add_string(&sub_h, &key[0], key.length, &value[0], value.length);
    HiBON string_hibon = cast(HiBON) sub_h.hibon;
    assert(string_hibon[key].get!string == value);

    // add it to a new hibon instance as a subhibon;
    HiBONT h;
    rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "Could not create hibon");
    string _key = "sub_doc_key";
    rt = tagion_hibon_add_hibon(&h, &_key[0], _key.length, &sub_h);
    assert(rt == ErrorCode.none);
    HiBON result = cast(HiBON) h.hibon;
    assert(result[_key].get!HiBON == string_hibon, "The read subhibon was not the same");
}

/** 
 * Add binary data to hibon instance
 * Params: 
 *   instance = pointer to the instance
 *   key = pointer to the key
 *   key_len = key length
 *   buf = pointer to the buffer to insert.
 *   buf_len = length of the buffer
 * Returns: 
 */
int tagion_hibon_add_binary(const(HiBONT*) instance,
                            const char* key,
                            const size_t key_len,
                            const uint8_t* buf,
                            const size_t buf_len) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            return ErrorCode.exception;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0..key_len].idup;
        immutable _buf = buf[0..buf_len].idup;
        h[_key] = _buf;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
unittest {
    HiBONT h;
    int rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "could not create hibon");
    string key = "some_key";
    immutable(ubyte[]) binary_data = [0,1,0,1];
    rt = tagion_hibon_add_binary(&h, &key[0], key.length, &binary_data[0], binary_data.length);
    assert(rt == ErrorCode.none);
    HiBON result = cast(HiBON) h.hibon;
    assert(result[key].get!(immutable(ubyte[])) == binary_data);
}

int tagion_hibon_add_time(const(HiBONT*) instance,
                    const char* key,
                    const size_t key_len,
                    const(int64_t) time) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            return ErrorCode.exception;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0..key_len].idup;
        h[_key] = sdt_t(time);
    } 
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
unittest {
    HiBONT h;
    int rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "could not create hibon");
    string key = "some_key";
    auto insert_time = sdt_t(12_345);

    rt = tagion_hibon_add_time(&h, &key[0], key.length, cast(int64_t) insert_time);
    assert(rt == ErrorCode.none, "could not add time");

    HiBON result = cast(HiBON) h.hibon;
    import tagion.hibon.HiBONBase : Type;
    assert(result[key].type == Type.TIME);
    assert(Document(result)[key].get!sdt_t == insert_time);
}

/** 
 * Add big number to hibon
 * Params:
 *   instance = pointer to the instance
 *   key = pointer to the key
 *   key_len = length of the key
 *   bigint_buf = big int buffer as serialized leb128
 *   bigint_buf_len = length of the buffer
 * Returns: ErrorCode
 */
int tagion_hibon_add_bigint(const(HiBONT*) instance,
                        const char* key,
                        const size_t key_len,
                        const uint8_t* bigint_buf,
                        const size_t bigint_buf_len) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            return ErrorCode.exception;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0..key_len].idup;
        auto buf = bigint_buf[0..bigint_buf_len];
        h[_key] = BigNumber(buf);
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
unittest {

    HiBONT h;
    int rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "could not create hibon");
    string key = "some_key";
    auto big_number = BigNumber(321);
    auto big_number_data = big_number.serialize;

    rt = tagion_hibon_add_bigint(&h, &key[0], key.length, &big_number_data[0], big_number_data.length);
    assert(rt == ErrorCode.none);
    HiBON result = cast(HiBON) h.hibon;
    assert(result[key].get!(BigNumber) == big_number);
}
                         
                    


mixin template add_T(T, string func_name) {
    pragma(mangle, func_name)
    extern(C) int add_T(const(HiBONT*) instance,
                        const char* key,
                        const size_t key_len,
                        const(T) value) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            return ErrorCode.exception;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0..key_len].idup;
        h[_key] = value;
    } 
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;

    }
    import std.format;
    enum mangled_name = format("extern(C) int %s(%s,%s,%s,%s);", func_name, "const(HiBONT*)", "const char*", "const size_t", T.stringof);
    mixin(mangled_name);
}

/** 
* Add boolean to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = bool to add
* Returns: ErrorCode
*/
mixin add_T!(bool, "tagion_hibon_add_bool");
/** 
* Add int32 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = int32 to add
* Returns: ErrorCode
*/
mixin add_T!(int32_t, "tagion_hibon_add_int32");
/** 
* Add int64 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = int64 to add
* Returns: ErrorCode
*/
mixin add_T!(int64_t, "tagion_hibon_add_int64");
/** 
* Add uint32 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = uint32 to add
* Returns: ErrorCode
*/
mixin add_T!(uint32_t, "tagion_hibon_add_uint32");
/** 
* Add uint64 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = uint64 to add
* Returns: ErrorCode
*/
mixin add_T!(uint64_t, "tagion_hibon_add_uint64");
/** 
* Add float32 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = float32 to add
* Returns: ErrorCode
*/
mixin add_T!(float, "tagion_hibon_add_float32");
/** 
* Add float64 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = float64 to add
* Returns: ErrorCode
*/
mixin add_T!(double, "tagion_hibon_add_float64");

void testAddFunc(T)(
    T call_value, 
    int function(const(HiBONT*), const char*, const size_t, T) func) 
{
    HiBONT h;
    int rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none);
    string key = "some_key";

    rt = func(&h, &key[0], key.length, call_value);
    assert(rt == ErrorCode.none, "could not add time");
    HiBON result = cast(HiBON) h.hibon;

    assert(result[key].get!T == call_value);
}

unittest {
    import std.stdio;

    testAddFunc!(bool)(true, &tagion_hibon_add_bool);
    testAddFunc!(int)(42, &tagion_hibon_add_int32);
    testAddFunc!(long)(long(42), &tagion_hibon_add_int64);
    testAddFunc!(uint)(uint(42), &tagion_hibon_add_uint32);
    testAddFunc!(ulong)(ulong(42), &tagion_hibon_add_uint64);
    testAddFunc!(float)(21.1f, &tagion_hibon_add_float32); 
    testAddFunc!(double)(321.312312f, &tagion_hibon_add_float64);
}
