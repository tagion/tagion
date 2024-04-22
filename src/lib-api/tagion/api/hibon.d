/// API for using hibon
module tagion.api.hibon;
import tagion.api.errors;
import tagion.hibon.HiBON;

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
        if (instance !is null && instance.magic_byte != MAGIC_HIBON) {
            return ErrorCode.none;
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
    import tagion.hibon.Document;
    HiBONT h;
    int rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "could not create hibon");
    string key = "some_key";
    string value = "some_value";
    rt = tagion_hibon_add_string(&h, &key[0], key.length, &value[0], value.length);
    HiBON string_hibon = cast(HiBON) h.hibon;
    assert(string_hibon[key].get!string == value);
}


// int tagion_hibon_add_document(const(void*) instance) {}
// int tagion_hibon_add_binary(const(void*) instance) {}
// int tagion_hibon_add_boolean(const(void*) instance) {}



