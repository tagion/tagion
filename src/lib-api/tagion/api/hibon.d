/// API for using hibon
module tagion.api.hibon;
import tagion.api.errors;
import tagion.hibon.HiBON;
import core.stdc.stdint;
import tagion.hibon.Document;

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

/** 
 * Add boolean to hibon instance
 * Params:
 *   instance = pointer to the instance
 *   key = pointer to the key
 *   key_len = length of the key
 *   value = bool to add
 * Returns: 
 */
int tagion_hibon_add_bool(const(HiBONT*) instance,
                        const char* key,
                        const size_t key_len,
                        const bool value) {
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
                            
///
unittest {
    HiBONT h;
    int rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "could not create hibon");
    string key = "some_key";
    bool wowo = true;

    rt = tagion_hibon_add_bool(&h, &key[0], key.length, wowo);
    assert(rt == ErrorCode.none, "could not add bool");

    HiBON result = cast(HiBON) h.hibon;
    assert(result[key].get!bool == wowo);
}


