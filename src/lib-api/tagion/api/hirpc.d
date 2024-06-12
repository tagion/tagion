/// C-API for creating hirpcs
module tagion.api.hirpc;

import tagion.api.errors;

import tagion.communication.HiRPC;
import tagion.hibon.Document;

extern(C):
nothrow:

int tagion_hirpc_create_sender(
        const char* method,
        const size_t method_len,
        ubyte* param,
        const size_t param_len,
        ubyte** out_doc,
        size_t* out_doc_len) {
    try {
        const doc = Document(cast(immutable)param[0 .. param_len]);
        string method_name = cast(immutable)method[0 .. method_len];

        ubyte[] result_sender = cast(ubyte[])HiRPC(null).action(method_name, doc).serialize;
        *out_doc = &result_sender[0];
        *out_doc_len = result_sender.length;
        return ErrorCode.none;
    }
    catch(Exception e) {
        last_error = e;
        return ErrorCode.exception;
    }
}
