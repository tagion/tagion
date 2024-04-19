/// API for using document
module tagion.api.document;

import tagion.api.errors;
import tagion.hibon.Document;
import tagion.basic.tagionexceptions;
import core.stdc.stdint;
import std.stdio;
import core.lifetime;
import tagion.hibon.HiBON;
extern(C):

version(unittest) {
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

/** 
 * Get an integer from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned integer
 * Returns: ErrorCode
 */
int tagion_document_get_int(const Document.Element* element, int* value) {
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
    int insert_int = 42;
    h["i32"]=insert_int;
    const doc = Document(h);
    Document.Element elm_i32;

    // get element that exists
    int rt = tagion_document(&doc.data[0], doc.data.length, &key_i32[0], key_i32.length, &elm_i32);
    assert(rt == ErrorCode.none, "Get Document.element returned error");

    // get the integer
    int value;
    rt = tagion_document_get_int(&elm_i32, &value);
    assert(rt == ErrorCode.none, "Get integer returned error");
    assert(value == insert_int, "The document int was not the same");
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
        stdout.flush;
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
