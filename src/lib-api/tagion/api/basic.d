/// API for basic functions
module tagion.api.basic;
import tagion.basic.Types;
import tagion.api.errors;
import core.stdc.stdint;

extern (C):



version (unittest) {
}
else {
nothrow:
}

int tagion_basic_encode_base64url(const(uint8_t*) buf, 
        const size_t buf_len,
        char** str,
        size_t* str_len) {
    try {
        const _buf = buf[0..buf_len].idup;

        const encoded = _buf.encodeBase64;

        *str = cast(char*) &encoded[0];
        *str_len = encoded.length;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

int tagion_basic_get_dart_index(const(uint8_t*) buf, 
        const size_t buf_len,
        uint8_t** dart_index_buf,
        size_t* dart_index_buf_len) {
    import tagion.crypto.SecureNet;
    import tagion.dart.DARTBasic;
    import tagion.hibon.Document;
    try {
        const _buf = buf[0..buf_len].idup;
        const doc = Document(_buf);

        const dart_index = dartIndex(hash_net, doc);

        *dart_index_buf= cast(uint8_t*) &dart_index[0];
        *dart_index_buf_len= dart_index.length;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}
