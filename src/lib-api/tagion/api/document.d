/// API for using document
module tagion.api.document;

import tagion.api.errors;
import tagion.hibon.Document;
import tagion.basic.tagionexceptions;
import core.stdc.stdint;
import std.stdio;
import core.lifetime;
extern(C):

version(unittest) {
import tagion.hibon.HiBON;
} 
else {
nothrow:
}

/** 
 * Get a Document element
 * Params:
 *   buf = the document buffer
 *   buf_len = length of the document buffer
 *   key = key to get
 *   key_len = length of key
 *   element = pointer to the returned element
 * Returns: ErrorCode
 */
int tagion_document(
    const uint8_t* buf, 
    const size_t buf_len, 
    const char* key, 
    const size_t key_len, 
    Document.Element* element) {
    try {
        immutable _buf=cast(immutable)buf[0..buf_len]; 
        immutable _key=cast(immutable)key[0..key_len];
        const doc = Document(_buf);
        const doc_error = doc.valid;
        if (doc_error !is Document.Element.ErrorCode.NONE) {
            return cast(int)doc_error;
        }
        auto doc_elm=doc[_key];
        copyEmplace(doc_elm, *element);
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/** 
 * Get a document element from index
 * Params:
 *   buf = the document buffer
 *   buf_len = length of the buffer
 *   index = index to
 *   element = 
 * Returns: 
 */
int tagion_document_array(
    const uint8_t* buf, 
    const size_t buf_len, 
    const size_t index, 
    Document.Element* element) {
    try {
        immutable _buf=cast(immutable)buf[0..buf_len]; 
        const doc = Document(_buf);
        const doc_error = doc.valid;
        if (doc_error !is Document.Element.ErrorCode.NONE) {
            return cast(int)doc_error;
        }
        auto doc_elm=doc[index];
        copyEmplace(doc_elm, *element);
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/** 
 * Get an sub doc from a document
 * Params:
 *   element = element to get
 *   buf = returned buffer
 *   buf_len = length of buffer
 * Returns: ErrorCode
 */
int tagion_document_get_document(const Document.Element* element, uint8_t** buf, size_t* buf_len) {
    try {
        auto sub_doc = element.get!Document;
        const sub_doc_error = sub_doc.valid;
        if (sub_doc_error !is Document.Element.ErrorCode.NONE) {
            return cast(int) sub_doc_error;
        }
        auto data = sub_doc.data;
        *buf = cast(uint8_t*) &data[0];
        *buf_len = sub_doc.full_size;
    } catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

unittest {
    auto sub_hibon = new HiBON;
    sub_hibon["i32"] = "hello";
    auto sub_doc = Document(sub_hibon);
    string key_doc = "doc";
    auto h = new HiBON;
    h[key_doc] = sub_doc;
    const doc = Document(h);

    Document.Element elm_doc;
    int rt = tagion_document(&doc.data[0], doc.data.length, &key_doc[0], key_doc.length, &elm_doc);
    assert(rt == ErrorCode.none, "Get document element string returned error");

    uint8_t* buf;
    size_t buf_len;

    rt = tagion_document_get_document(&elm_doc, &buf, &buf_len);
    assert(rt == ErrorCode.none, "Get subdoc returned error");

    auto read_data = cast(immutable) buf[0..buf_len];
    assert(sub_doc == Document(read_data), "read doc was not the same");
}

/** 
 * Get an string from a document
 * Params:
 *   element = element to get
 *   value = pointer to the string
 *   str_len = length of string
 * Returns: ErrorCode 
 */
int tagion_document_get_string(const Document.Element* element, char** value, size_t* str_len) {
    try {
        auto str = element.get!string;
        *value = cast(char*) &str[0];
        *str_len = str.length;
    } catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

unittest {
    auto h = new HiBON;
    string key_string = "string";
    h[key_string] = "wowo";
    const doc = Document(h);
    Document.Element elm_string;

    int rt = tagion_document(&doc.data[0], doc.data.length, &key_string[0], key_string.length, &elm_string);
    assert(rt == ErrorCode.none, "Get document element string returned error");

    char* str_value;
    size_t str_len;

    rt = tagion_document_get_string(&elm_string, &str_value, &str_len);
    assert(rt == ErrorCode.none, "get string returned error");

    auto str = str_value[0..str_len];
    assert(str == "wowo", "read string was different"); 
}

unittest {
    auto h = new HiBON;
    h = ["hey0", "hey1", "hey2"];
    const doc = Document(h);
    Document.Element elm_string;
    int rt = tagion_document_array(&doc.data[0], doc.data.length, 0, &elm_string);
    assert(rt == ErrorCode.none, "get array index returned error");
    char* str_value;
    size_t str_len;

    rt = tagion_document_get_string(&elm_string, &str_value, &str_len);
    assert(rt == ErrorCode.none, "get string returned error");
    auto str = str_value[0..str_len];
    assert(str == "hey0", "read string was different"); 

    // read index to trigger range error
    rt = tagion_document_array(&doc.data[0], doc.data.length, 5, &elm_string);
    assert(rt == ErrorCode.exception, "should throw error on undefined index");
}


/** 
 * Get binary from a document
 * Params:
 *   element = element to get
 *   buf = pointer to read buffer
 *   buf_len = pointer to buffer length
 * Returns: ErrorCode
 */
int tagion_document_get_binary(const Document.Element* element, uint8_t** buf, size_t* buf_len) {
    try {
        auto data = element.get!(immutable(ubyte[]));
        *buf = cast(uint8_t*) &data[0];
        *buf_len = data.length; 
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

unittest {
    auto h = new HiBON;
    string key_binary = "binary";
    immutable(ubyte[]) binary_data = [0,1,0,1];
    h[key_binary] = binary_data;
    const doc = Document(h);

    Document.Element elm_binary;
    int rt = tagion_document(&doc.data[0], doc.data.length, &key_binary[0], key_binary.length, &elm_binary);
    assert(rt == ErrorCode.none, "Get document element binary returned error");

    uint8_t* buf;
    size_t buf_len;
    rt = tagion_document_get_binary(&elm_binary, &buf, &buf_len);
    assert(rt == ErrorCode.none);

    auto read_data = cast(immutable) buf[0..buf_len];

    assert(binary_data == read_data); 
}


/** 
 * Get a bool from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned bool
 * Returns: ErrorCode
 */
int tagion_document_get_bool(const Document.Element* element, bool* value) {
    try {
        *value = element.get!bool; 
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

unittest {
    auto h = new HiBON;
    string key_bool = "bool";
    h[key_bool] = true;
    const doc = Document(h);

    Document.Element elm_bool;
    int rt = tagion_document(&doc.data[0], doc.data.length, &key_bool[0], key_bool.length, &elm_bool);
    assert(rt == ErrorCode.none, "Get document element bool returned error");

    bool value;
    rt = tagion_document_get_bool(&elm_bool, &value);
    assert(rt == ErrorCode.none, "get bool returned error");

    assert(value == true, "did not read bool");
}

/** 
 * Get time from a document element
 * Params:
 *   element = element to get 
 *   time = pointer to the returned time
 * Returns: ErrorCode
 */
int tagion_document_get_time(const Document.Element* element, int64_t* time) {
    import tagion.utils.StdTime;
    try {
        *time = cast(long) element.get!sdt_t;
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

unittest {
    auto h = new HiBON;
    string key_time = "time";
    import tagion.utils.StdTime;
    auto insert_time = sdt_t(12_345);
    h[key_time] = insert_time;
    const doc = Document(h);

    Document.Element elm_time;
    int rt = tagion_document(&doc.data[0], doc.data.length, &key_time[0], key_time.length, &elm_time);
    assert(rt == ErrorCode.none, "Get document element time returned error");

    long value;
    rt = tagion_document_get_time(&elm_time, &value);
    assert(rt == ErrorCode.none, "get time returned error");

    assert(value == cast(long) insert_time, "did not read time");
}

/** 
 * Get an i32 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned i32
 * Returns: ErrorCode
 */
int tagion_document_get_int32(const Document.Element* element, int32_t* value) {
    try {
        *value = element.get!int; 
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}
///
unittest {
    auto h = new HiBON;
    string key_i32="i32";
    h["i32"]=42;
    const doc = Document(h);
    Document.Element elm_i32;

    // get element that exists
    int rt = tagion_document(&doc.data[0], doc.data.length, &key_i32[0], key_i32.length, &elm_i32);
    assert(rt == ErrorCode.none, "Get Document.element returned error");

    // try to get element not present should throw
    Document.Element elm_none;
    string key_time="time";
    rt = tagion_document(&doc.data[0], doc.data.length, &key_time[0], key_time.length, &elm_none);
    assert(rt == ErrorCode.exception, "Should throw an error");
}

///
unittest {
    auto h = new HiBON;
    string key_i32="i32";
    int insert_int = 42;
    h["i32"]=insert_int;
    const doc = Document(h);
    Document.Element elm_i32;

    // get element that exists
    int rt = tagion_document(&doc.data[0], doc.data.length, &key_i32[0], key_i32.length, &elm_i32);
    assert(rt == ErrorCode.none, "Get Document.element returned error");

    // get the integer
    int value;
    rt = tagion_document_get_int32(&elm_i32, &value);
    assert(rt == ErrorCode.none, "Get integer returned error");
    assert(value == insert_int, "The document int was not the same");
}
/** 
 * Get an i64 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned i64
 * Returns: ErrorCode
 */
int tagion_document_get_int64(const Document.Element* element, int64_t* value) {
    try {
        *value = element.get!long; 
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/** 
 * Get an uint32 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned uint32
 * Returns: ErrorCode
 */
int tagion_document_get_uint32(const Document.Element* element, uint32_t* value) {
    try {
        *value = element.get!uint; 
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}
/** 
 * Get an uint64 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned uint64
 * Returns: ErrorCode
 */
int tagion_document_get_uint64(const Document.Element* element, uint64_t* value) {
    try {
        *value = element.get!ulong; 
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}


/** 
 * Get an f32 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned f32
 * Returns: ErrorCode
 */
int tagion_document_get_float32(const Document.Element* element, float* value) {
    try {
        *value = element.get!float;
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/** 
 * Get an f64 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned f64
 * Returns: ErrorCode
 */
int tagion_document_get_float64(const Document.Element* element, double* value) {
    try {
        *value = element.get!double;
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/** 
 * Get bigint from a document. Returned as serialized leb128 ubyte buffer
 * Params:
 *   element = element to get
 *   bigint_buf = pointer to read buffer
 *   bigint_buf_len = pointer to buffer length
 * Returns: ErrorCode
 */
int tagion_document_get_bigint(const Document.Element* element, uint8_t** bigint_buf, size_t* bigint_buf_len) {
    import tagion.hibon.BigNumber;

    try {
        auto big_number = element.get!BigNumber;
        auto data = big_number.serialize;
        *bigint_buf = cast(uint8_t*) &data[0];
        *bigint_buf_len = data.length; 
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

