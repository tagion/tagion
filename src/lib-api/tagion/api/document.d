module tagion.api.document;

import tagion.api.errors;
import tagion.hibon.Document;
import tagion.basic.tagionexceptions;
import core.stdc.stdint;

extern(C):
nothrow:

int tagion_hibon_document_get_int(
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
        auto element_data = doc[_key].data;
        element=cast(Document.Element*)&element_data[0];
        //element=doc[_key].data;
    }
    catch (Exception e) {
        return ErrorCode.exception;
    }
    return ErrorCode.none;
    
}
