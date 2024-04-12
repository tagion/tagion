module tagion.api.errors;

import std.exception;

extern(C):
nothrow:

enum ErrorCode {
    none = 0,
    exception = -1, 
}

static Exception last_error;

void tagion_error_text(const(char)* msg, size_t* msg_len) {
    msg=null;
    *msg_len=0;
    if (last_error) {
        msg=&last_error.msg[0];
        *msg_len=last_error.msg.length;
    }
}

void tagion_clear_error() {
    last_error = null;
}

