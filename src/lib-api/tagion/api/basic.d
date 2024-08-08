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

/// Start druntime https://dlang.org/library/core/runtime/rt_init.html
export int rt_init();

/// Stop druntime https://dlang.org/library/core/runtime/rt_term.html
export int rt_term();

/**
  starts druntime
  
  The druntime should be started before any other functions are called
*/
int start_rt() {
    import core.runtime : rt_init;
    if (__runtimeStatus is DrtStatus.DEFAULT_STS) {
        __runtimeStatus = DrtStatus.STARTED;
        return rt_init;
    }
    return -1;
}

/// Terminating d-runtime
int stop_rt() {
    import core.runtime : rt_term;
    if (__runtimeStatus is DrtStatus.STARTED) {
        __runtimeStatus = DrtStatus.TERMINATED;
        return rt_term;
    }
    return -1;
}

nothrow:

/**

  Encode a buffer into a base64url string

  Params: 
      buf_ptr = a ptr to the buffer to encode
      buf_len = the length of the buffer

      str_ptr = the resulting base64url string
      str_len = the length of the result string
  Returns: 
      [tagion.api.errors.ErrorCode]

 */
int tagion_basic_encode_base64url(
    const(uint8_t*) buf_ptr,
    const size_t buf_len,
    char** str_ptr,
    size_t* str_len
) {
    try {
        const _buf = buf_ptr[0..buf_len];

        const encoded = _buf.encodeBase64;

        *str_ptr = cast(char*) &encoded[0];
        *str_len = encoded.length;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
    return ErrorCode.none;
}

/**

  Calculate the [dartindex](https://docs.tagion.org/docs/protocols/dart/dartindex) for a Document
  The dartindex is what is used to reference the document in the DART database
  
  Params:
    doc_ptr = The pointer to the serialized document
    doc_len = The length of the document

    dart_index_buf = The resulting dartindex
    dart_index_buf_len = The length of the resulting dartindex (should always be 32 bytes)

  Returns: 
      [tagion.api.errors.ErrorCode]

 */
int tagion_create_dartindex(
        const(uint8_t*) doc_ptr, 
        const size_t doc_len,
        uint8_t** dart_index_buf,
        size_t* dart_index_buf_len) {
    import tagion.crypto.SecureNet;
    import tagion.dart.DARTBasic;
    import tagion.hibon.Document;
    try {
        const _buf = doc_ptr[0..doc_len].idup;
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

/**

  Get the tagion revision info

  Params:
    str_ptr = The resulting revision string
    str_len = The length of the resulting string
  Returns: 
 */
int tagion_revision(char** str_ptr, size_t* str_len) {
    import tagion.tools.revision;
    *str_ptr = cast(char*) &revision_text[0];
    *str_len = revision_text.length;
    return ErrorCode.none;
}
