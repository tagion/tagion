/// API for basic functions
module tagion.api.basic;
import tagion.basic.Types;
import tagion.api.errors;
import core.stdc.stdint;

enum MAGIC : uint {
    WALLET = 0xA000_0001,
    HIBON = 0xB000_0001,
    SECURENET = 0xC000_0001,
}

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

int tagion_basic_get_dart_index(
        const(uint8_t*) buf, 
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
        *dart_index_buf_len = dart_index.length;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}


/// Variable, which represents the d-runtime status
__gshared DrtStatus __runtimeStatus = DrtStatus.DEFAULT_STS;

enum DrtStatus {
    DEFAULT_STS,
    STARTED,
    TERMINATED
}
// Staritng d-runtime
static int start_rt() {
    import core.runtime : rt_init;
    if (__runtimeStatus is DrtStatus.DEFAULT_STS) {
        __runtimeStatus = DrtStatus.STARTED;
        return rt_init;
    }
    return -1;
}

// Terminating d-runtime
static int stop_rt() {
    import core.runtime : rt_term;
    if (__runtimeStatus is DrtStatus.STARTED) {
        __runtimeStatus = DrtStatus.TERMINATED;
        return rt_term;
    }
    return -1;
}


int tagion_revision(char** value, size_t* str_len) {
    import tagion.tools.revision;
    *value = cast(char*) &revision_text[0];
    *str_len = revision_text.length;
    return ErrorCode.none;
}
