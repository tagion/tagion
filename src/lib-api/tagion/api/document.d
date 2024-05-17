/// API for using document
module tagion.api.document;

import tagion.api.errors;
import tagion.hibon.Document;
import tagion.basic.tagionexceptions;
import core.stdc.stdint;
version(C_API_DEBUG) {
import std.stdio;
}
import core.lifetime;
import tagion.utils.StdTime;
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
 * Return the version of the document
 * Params:
 *   buf = doc buf 
 *   buf_len = doc len
 *   ver = 
 * Returns: ErrorCode
 */
int tagion_document_get_version(
    const uint8_t* buf, 
    const size_t buf_len,
    uint32_t* ver) {
    try {
        immutable _buf=cast(immutable)buf[0..buf_len]; 
        const doc = Document(_buf);
        const doc_error = doc.valid;
        if (doc_error !is Document.Element.ErrorCode.NONE) {
            return cast(int)doc_error;
        }
        *ver = doc.ver();
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
    h["version_test"] = 2;
    const doc = Document(h);

    uint ver = 10; // set the version equal to something else since current ver is 0 
    int rt = tagion_document_get_version(&doc.data[0], doc.data.length, &ver);
    assert(rt == ErrorCode.none);
    import tagion.hibon.HiBONBase : HIBON_VERSION;
    assert(ver == HIBON_VERSION);
}

/** 
 * Get document record type
 * Params:
 *   buf = 
 *   buf_len = 
 *   record_name = 
 *   record_name_len = 
 * Returns: ErrorCode
 */
int tagion_document_get_record_name(
    const uint8_t* buf, 
    const size_t buf_len, 
    char** record_name, 
    size_t* record_name_len) {
    import tagion.hibon.HiBONRecord : recordName;
    try {
        immutable _buf=cast(immutable)buf[0..buf_len]; 
        const doc = Document(_buf);
        const doc_error = doc.valid;
        if (doc_error !is Document.Element.ErrorCode.NONE) {
            return cast(int)doc_error;
        }
        string data = doc.recordName;
        if (data !is string.init) {
            *record_name = cast(char*) &data[0];
            *record_name_len = data.length;
        }
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

///
unittest {
    import tagion.hibon.HiBONRecord : recordType, HiBONRecord;
    enum some_record = "SomeRecord";
    @recordType(some_record)
    static struct S {
        int test;
        mixin HiBONRecord;
    }
    S s;
    s.test = 5;
    const doc = s.toDoc;

    char* record_name_value;
    size_t record_name_len;
    int rt = tagion_document_get_record_name(&doc.data[0], doc.data.length, &record_name_value, &record_name_len);
    assert(rt == ErrorCode.none);

    const record_name = record_name_value[0..record_name_len];
    assert(record_name == some_record); 
}


/** 
 * Get document error code
 * Params:
 *   buf = doc buf
 *   buf_len = doc len 
 *   error_code = pointer to error code
 * Returns: ErrorCode
 */
int tagion_document_valid(const uint8_t* buf, const size_t buf_len, int32_t* error_code) {
    try {
        immutable _buf=cast(immutable)buf[0..buf_len]; 
        const doc = Document(_buf);
        *error_code = cast(int) doc.valid;
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
    h["good"] = "document";
    const doc = Document(h);

    int error_code = 7;
    int rt = tagion_document_valid(&doc.data[0], doc.data.length, &error_code);
    assert(rt == ErrorCode.none);
    assert(error_code == Document.Element.ErrorCode.NONE);
}

/** 
 * Get a document element from index
 * Params:
 *   buf = the document buffer
 *   buf_len = length of the buffer
 *   index = index to
 *   element = 
 * Returns: ErrorCode
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

/// Format to use for tagion_document_get_text
enum DocumentTextFormat {
    JSON, 
    PRETTYJSON, 
    BASE64, 
    HEX,
}

/** 
 * Get document as string
 * Params:
 *   buf = doc buffer
 *   buf_len = doc len
 *   text_format = See DocumentTextFormat for supported formats
 *   str = returned pointer
 *   str_len = returned str len
 * Returns: 
 */
int tagion_document_get_text(
    const uint8_t* buf, 
    const size_t buf_len, 
    const int text_format,
    char** str, 
    size_t* str_len
    ) {
    import tagion.hibon.HiBONJSON;
    import tagion.hibon.HiBONtoText;
    import std.format;
    try {
        immutable _buf=cast(immutable)buf[0..buf_len]; 
        const doc = Document(_buf);
        const doc_error = doc.valid;
        if (doc_error !is Document.Element.ErrorCode.NONE) {
            return cast(int)doc_error;
        }

        const fmt = cast(DocumentTextFormat) text_format;

        string text;
        with (DocumentTextFormat) {
            switch(fmt) {
                case JSON:
                    text = doc.toJSON.toString;
                    break;
                case PRETTYJSON:
                    text = doc.toPretty;
                    break;
                case BASE64:
                    text = doc.encodeBase64;
                    break;
                case HEX:
                    text = format("%(%02x%)", doc.serialize);
                    break;
                default:
                    return ErrorCode.error;
            }
        }
        *str = cast(char*) &text[0];
        *str_len = text.length;
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }

    return ErrorCode.none;
}

/// 
unittest {
    import tagion.hibon.HiBONJSON;
    import tagion.hibon.HiBONtoText;
    import std.format;

    auto h = new HiBON;
    h["hai"] = "bon";
    const doc = Document(h);

    // hex
    char* str_value;
    size_t str_len;
    int rt = tagion_document_get_text(&doc.data[0], doc.data.length, DocumentTextFormat.HEX, &str_value, &str_len); 
    assert(rt == ErrorCode.none);
    auto str = str_value[0..str_len];
    assert(str == format("%(%02x%)", doc.serialize));

    // json
    rt = tagion_document_get_text(&doc.data[0], doc.data.length, DocumentTextFormat.JSON, &str_value, &str_len); 
    assert(rt == ErrorCode.none);
    str = str_value[0..str_len];
    assert(str == doc.toJSON.toString);


    // jsonpretty
    rt = tagion_document_get_text(&doc.data[0], doc.data.length, DocumentTextFormat.PRETTYJSON, &str_value, &str_len); 
    assert(rt == ErrorCode.none);
    str = str_value[0..str_len];
    assert(str == doc.toPretty);

    // base64
    rt = tagion_document_get_text(&doc.data[0], doc.data.length, DocumentTextFormat.BASE64, &str_value, &str_len); 
    assert(rt == ErrorCode.none);
    str = str_value[0..str_len];
    assert(str == doc.encodeBase64);

    // none existing format
    rt = tagion_document_get_text(&doc.data[0], doc.data.length, 100, &str_value, &str_len); 
    assert(rt == ErrorCode.error);
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

///
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
        version(C_API_DEBUG) {
        writefln("doc elem ptr %s", element);
        }
        auto str = element.get!string;
        version(C_API_DEBUG) {
        writefln("read string: %s", str);
        }
        *value = cast(char*) &str[0];
        *str_len = str.length;
    } catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}
///
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
///
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

///
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
///
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


template get_T(T) {
    int get_T(const Document.Element* element, T* value) {
        try {
            *value = element.get!(T);
        }
        catch(Exception e) {
            last_error = e;
            return ErrorCode.exception;
        }
        return ErrorCode.none;
    }
}

/** 
 * Get a bool from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned bool
 * Returns: ErrorCode
 */
int tagion_document_get_bool(const Document.Element* element, bool* value) {
    return get_T!bool(__traits(parameters));
}

/** 
 * Get an i32 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned i32
 * Returns: ErrorCode
 */
int tagion_document_get_int32(const Document.Element* element, int32_t* value) {
    return get_T!int32_t(__traits(parameters));
}

/** 
 * Get an i64 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned i64
 * Returns: ErrorCode
 */
int tagion_document_get_int64(const Document.Element* element, int64_t* value) {
    return get_T!int64_t(__traits(parameters));
}
/** 
 * Get an uint32 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned uint32
 * Returns: ErrorCode
 */
int tagion_document_get_uint32(const Document.Element* element, uint32_t* value) {
    return get_T!uint32_t(__traits(parameters));
}

/** 
 * Get an uint64 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned uint64
 * Returns: ErrorCode
 */
int tagion_document_get_uint64(const Document.Element* element, uint64_t* value) {
    return get_T!uint64_t(__traits(parameters));
}

/** 
 * Get an f32 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned f32
 * Returns: ErrorCode
 */
int tagion_document_get_float32(const Document.Element* element, float* value) {
    return get_T!float(__traits(parameters));
}

/** 
 * Get an f64 from a document element
 * Params:
 *   element = element to get
 *   value = pointer to the returned f64
 * Returns: ErrorCode
 */
int tagion_document_get_float64(const Document.Element* element, double* value) {
    return get_T!double(__traits(parameters));
}

void testGetFunc(T)(
    T h_value,
    int function(const Document.Element*, T* value) func)
{
    auto h = new HiBON;
    string key = "some_keyT";
    h[key] = h_value;
    const doc = Document(h);
    Document.Element elmT;
    int rt = tagion_document(&doc.data[0], doc.data.length, &key[0], key.length, &elmT);
    assert(rt == ErrorCode.none);

    T get_value;
    rt = func(&elmT, &get_value);
    import std.format;
    assert(rt == ErrorCode.none, format("get %s returned error", T.stringof));
    assert(get_value == h_value, format("returned value for %s was not the same", T.stringof));
}

unittest {
    testGetFunc!(bool)(true, &tagion_document_get_bool);
    testGetFunc!(int)(42, &tagion_document_get_int32);
    testGetFunc!(long)(long(42), &tagion_document_get_int64);
    testGetFunc!(uint)(uint(42), &tagion_document_get_uint32);
    testGetFunc!(ulong)(ulong(42), &tagion_document_get_uint64);
    testGetFunc!(float)(21.1f, &tagion_document_get_float32); 
    testGetFunc!(double)(321.312312f, &tagion_document_get_float64);
}
