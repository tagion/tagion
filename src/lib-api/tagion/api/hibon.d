/// API for using hibon

module tagion.api.hibon;

import core.stdc.stdint;
import core.memory;

import std.bitmanip;

import tagion.api.errors;
import tagion.api.basic;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import tagion.utils.StdTime;
import tagion.hibon.BigNumber;

private enum INVALID_HIBON_INSTANCE =  "Empty or none hibon instance";

extern (C):

version(unittest) {
} else {
nothrow:
}

enum MAGIC_HIBON = MAGIC.HIBON;

/// HiBON Type
struct HiBONT {
    int magic_byte = MAGIC.HIBON;
    void* hibon;
}


void* mymalloc(size_t size) {
    import core.stdc.stdlib;
    return malloc(size);
}

void mydealloc(void* ptr) {
    import core.stdc.stdlib;

    free(ptr);
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
            set_error_text = "HiBON instance is null";
            return ErrorCode.error;
        }
        instance.hibon = cast(void*) new HiBON;
        instance.magic_byte = MAGIC_HIBON;
    }
    catch (Exception e) {
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

/// Free a HiBON object
void tagion_hibon_free(HiBONT* instance) {
    auto hibon = cast(HiBON)instance.hibon;
    destroy(hibon);
    GC.free(instance);
}

///
int tagion_hibon_has_member(const HiBONT* instance, const char* str, size_t str_len, bool* result) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        scope string key = cast(immutable)str[0..str_len];
        *result = h.hasMember(key);
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
int tagion_hibon_has_member_index(const HiBONT* instance, size_t index, bool* result) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        *result = h.hasMember(index);
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
int tagion_hibon_remove_by_key(HiBONT* instance, const char* str, size_t str_len) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        scope string key = cast(immutable)str[0..str_len];
        h.remove(key);
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
int tagion_hibon_remove_by_index(HiBONT* instance, size_t index) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        h.remove(index);
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
unittest {
    HiBONT* h = new HiBONT;
    int rc = tagion_hibon_create(h);
    assert(rc == ErrorCode.none);

    const string key = "a";
    rc = tagion_hibon_add_bool(h, &key[0], key.length, true);
    assert(rc == ErrorCode.none);

    bool result;
    rc = tagion_hibon_has_member(h, &key[0], key.length, &result);
    assert(rc == ErrorCode.none);
    assert(result == true);

    rc = tagion_hibon_remove_by_key(h, &key[0], key.length);
    assert(rc == ErrorCode.none);
    rc = tagion_hibon_has_member(h, &key[0], key.length, &result);
    assert(rc == ErrorCode.none);
    assert(result == false);
}

/** 
 *  Get the string representation of a hibon
 *
 *  Params:
 *    instance = Reference to the hibon object instance
 *    text_format = [tagion.api.document.DocumentTextFormat]
 *    str = reference to the returned string
 *    str_len = The length of the returned string
 *  Returns: [tagion.api.errors.ErrorCode]
*/
int tagion_hibon_get_text(const(HiBONT*) instance, int text_format, char** str, size_t* str_len) {
    import tagion.hibon.HiBONJSON;
    import tagion.hibon.HiBONtoText;
    import tagion.api.document : DocumentTextFormat;

    try {
        const fmt = cast(DocumentTextFormat) text_format;

        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;

        string text;
        with (DocumentTextFormat) {
            switch(fmt) {
                case JSON:
                    scope const doc = Document(h);
                    text = doc.toJSON.toString; 
                    break;
                case PRETTYJSON:
                    text = h.toPretty;
                    break;
                default:
                    set_error_text = "Invalid format";
                    return ErrorCode.error;
            }
        }
        *str = cast(char*) &text[0];
        *str_len = text.length;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/** 
 * Convert a hibon to a document
 * Params:
 *   instance = HiBONT instance
 *   buf = the returned buf ptr
 *   buf_len = length of the buf
 * Returns: ErrorCode
 */
int tagion_hibon_get_document(const(HiBONT*) instance, uint8_t** buf, size_t* buf_len) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const doc = Document(h);
        const data = doc.serialize;
        *buf = cast(uint8_t*) &data[0];
        *buf_len = data.length;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/// todoc
unittest {
    HiBONT h;
    int rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "could not create hibon");
    string key = "some_key";
    string value = "some_value";
    rt = tagion_hibon_add_string(&h, &key[0], key.length, &value[0], value.length);

    HiBON string_hibon = cast(HiBON) h.hibon;
    const doc = Document(string_hibon);

    uint8_t* buf;
    size_t buf_len;

    rt = tagion_hibon_get_document(&h, &buf, &buf_len);
    assert(rt == ErrorCode.none);
    auto read_data = cast(immutable) buf[0..buf_len];
    assert(doc == Document(read_data));
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
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0 .. key_len].idup;
        const _value = value[0 .. value_len].idup;
        h[_key] = _value;
    }
    catch (Exception e) {
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
int tagion_hibon_add_document(
        HiBONT* instance,
        const char* key,
        const size_t key_len,
        const(uint8_t*) buf,
        const size_t buf_len) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0 .. key_len].idup;
        immutable _buf = buf[0 .. buf_len].idup;
        const doc = Document(_buf);
        const doc_error = doc.valid;
        if (doc_error !is Document.Element.ErrorCode.NONE) {
            return cast(int) doc_error;
        }
        h[_key] = doc;
    }
    catch (Exception e) {
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
 * Add document to hibon by index
 * Params:
 *   instance = pointer to the hibon instance
 *   index = The index to put the Document at
 *   buf = pointer to the document buffer
 *   buf_len = length of the buffer
 * Returns: [tagion.api.errors.ErrorCode]
 */
int tagion_hibon_add_index_document(
        HiBONT* instance,
        const size_t index,
        const(uint8_t*) buf,
        const size_t buf_len) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        immutable _buf = buf[0 .. buf_len].idup;
        const doc = Document(_buf);
        const doc_error = doc.valid;
        if (doc_error !is Document.Element.ErrorCode.NONE) {
            return cast(int) doc_error;
        }
        h[index] = doc;
    }
    catch (Exception e) {
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
    const key = 0;

    rt = tagion_hibon_add_index_document(&h, key, &doc.data[0], doc.data.length);
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
int tagion_hibon_add_hibon(
        const(HiBONT*) instance,
        const char* key,
        const size_t key_len,
        const(HiBONT*) sub_instance
) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        // do the same for the subinstance
        if (sub_instance is null || sub_instance.magic_byte != MAGIC_HIBON) {
            set_error_text = "Invalid hibon subinstance";
            return ErrorCode.error;
        }
        HiBON sub_h = cast(HiBON) sub_instance.hibon;
        const _key = key[0 .. key_len].idup;
        h[_key] = sub_h;
    }
    catch (Exception e) {
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
 * Add hibon to hibon instance by index
 * Params:
 *   instance = pointer to the hibon instance
 *   index = The index to pute the hibon add
 *   sub_instance = pointer to the sub hibon instance that needs to be inserted
 * Returns: ErrorCode
 */
int tagion_hibon_add_index_hibon(
        const(HiBONT*) instance,
        const size_t index,
        const(HiBONT*) sub_instance
) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        // do the same for the subinstance
        if (sub_instance is null || sub_instance.magic_byte != MAGIC_HIBON) {
            set_error_text = "Invalid hibon subinstance";
            return ErrorCode.error;
        }
        HiBON sub_h = cast(HiBON) sub_instance.hibon;
        h[index] = sub_h;
    }
    catch (Exception e) {
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
    const key = "some_key";
    string value = "some_value";
    rt = tagion_hibon_add_string(&sub_h, &key[0], key.length, &value[0], value.length);
    HiBON string_hibon = cast(HiBON) sub_h.hibon;
    assert(string_hibon[key].get!string == value);

    // add it to a new hibon instance as a subhibon;
    HiBONT h;
    rt = tagion_hibon_create(&h);
    assert(rt == ErrorCode.none, "Could not create hibon");
    const _key = 1;
    rt = tagion_hibon_add_index_hibon(&h, _key, &sub_h);
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
int tagion_hibon_add_binary(
        const(HiBONT*) instance,
        const char* key,
        const size_t key_len,
        const uint8_t* buf,
        const size_t buf_len
) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0 .. key_len].idup;
        immutable _buf = buf[0 .. buf_len].idup;
        h[_key] = _buf;
    }
    catch (Exception e) {
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
    immutable(ubyte[]) binary_data = [0, 1, 0, 1];
    rt = tagion_hibon_add_binary(&h, &key[0], key.length, &binary_data[0], binary_data.length);
    assert(rt == ErrorCode.none);
    HiBON result = cast(HiBON) h.hibon;
    assert(result[key].get!(immutable(ubyte[])) == binary_data);
}

/** 
 * Add binary data to hibon instance by index
 * Params: 
 *   instance = pointer to the instance
 *   index = The index to put the binary data at
 *   buf = pointer to the buffer to insert.
 *   buf_len = length of the buffer
 * Returns: [tagion.api.errors.ErrorCode]
 */
int tagion_hibon_add_index_binary(
        const(HiBONT*) instance,
        const size_t index,
        const uint8_t* buf,
        const size_t buf_len
) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        immutable _buf = buf[0 .. buf_len].idup;
        h[index] = _buf;
    }
    catch (Exception e) {
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
    const index = 1;
    immutable(ubyte[]) binary_data = [0, 1, 0, 1];
    rt = tagion_hibon_add_index_binary(&h, index, &binary_data[0], binary_data.length);
    assert(rt == ErrorCode.none);
    HiBON result = cast(HiBON) h.hibon;
    assert(result[index].get!(immutable(ubyte[])) == binary_data);
}

///
int tagion_hibon_add_time(const(HiBONT*) instance,
        const char* key,
        const size_t key_len,
        const(int64_t) time) {
    try {
        if (instance is null || instance.magic_byte != MAGIC_HIBON) {
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0 .. key_len].idup;
        h[_key] = sdt_t(time);
    }
    catch (Exception e) {
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
    assert(result[key].get!sdt_t == insert_time);
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
            set_error_text = INVALID_HIBON_INSTANCE;
            return ErrorCode.error;
        }
        HiBON h = cast(HiBON) instance.hibon;
        const _key = key[0 .. key_len].idup;
        auto buf = bigint_buf[0 .. bigint_buf_len];
        h[_key] = BigNumber(buf);
    }
    catch (Exception e) {
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

extern(D)
private
template add_T(T) {
    int add_T(const(HiBONT*) instance,
            const char* key,
            const size_t key_len,
            const(T) value) {
        try {
            if (instance is null || instance.magic_byte != MAGIC_HIBON) {
                return ErrorCode.exception;
            }
            HiBON h = cast(HiBON) instance.hibon;
            const _key = key[0 .. key_len].idup;
            h[_key] = value;
        }
        catch (Exception e) {
            last_error = e;
            return ErrorCode.exception;
        }
        return ErrorCode.none;

    }
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
int tagion_hibon_add_bool(const(HiBONT*) h, const char* key, const size_t key_len, bool value) {
    return add_T!bool(__traits(parameters));
}

/** 
* Add int32 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = int32 to add
* Returns: ErrorCode
*/
int tagion_hibon_add_int32(const(HiBONT*) h, const char* key, const size_t key_len, int32_t value) {
    return add_T!int32_t(__traits(parameters));
}

/** 
* Add int64 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = int64 to add
* Returns: ErrorCode
*/
int tagion_hibon_add_int64(const(HiBONT*) h, const char* key, const size_t key_len, long value) {
    return add_T!int64_t(__traits(parameters));
}

/** 
* Add uint32 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = uint32 to add
* Returns: ErrorCode
*/
int tagion_hibon_add_uint32(const(HiBONT*) h, const char* key, const size_t key_len, uint32_t value) {
    return add_T!uint32_t(__traits(parameters));
}

/** 
* Add uint64 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = uint64 to add
* Returns: ErrorCode
*/
int tagion_hibon_add_uint64(const(HiBONT*) h, const char* key, const size_t key_len, ulong value) {
    return add_T!uint64_t(__traits(parameters));
}

/** 
* Add float32 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = float32 to add
* Returns: ErrorCode
*/
int tagion_hibon_add_float32(const(HiBONT*) h, const char* key, const size_t key_len, float value) {
    return add_T!float(__traits(parameters));
}

/** 
* Add float64 to hibon instance
* Params:
*   instance = pointer to the instance
*   key = pointer to the key
*   key_len = length of the key
*   value = float64 to add
* Returns: ErrorCode
*/
int tagion_hibon_add_float64(const(HiBONT*) h, const char* key, const size_t key_len, double value) {
    return add_T!double(__traits(parameters));
}

version(unittest)
private
void testAddFunc(T)(
        T call_value,
        int function(const(HiBONT*), const char*, const size_t, T) func
) {
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

/// malloc test
unittest {
    import core.stdc.stdlib;

    void* h = malloc(HiBONT.sizeof);

    int rt = tagion_hibon_create(cast(HiBONT*) h);
    assert(rt == ErrorCode.none);

    const key = "example_key";
    const value = "example_value";

    rt = tagion_hibon_add_string(cast(HiBONT*) h, &key[0], key.length, &value[0], value.length); 
    assert(rt == ErrorCode.none);
}
