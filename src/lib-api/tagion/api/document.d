module tagion.api.document;

import tagion.api.errors;
import tagion.hibon.Document;
import tagion.basic.tagionexceptions;
import core.stdc.stdint;
import std.stdio;
import core.lifetime;
extern(C):
nothrow:

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

int tagion_document_get_int(const Document.Element* elmenet, int* value) {
    try {
        *value = elmenet.get!int; 
    }
    catch (Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}
