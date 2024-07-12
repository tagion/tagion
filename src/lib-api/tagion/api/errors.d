module tagion.api.errors;

import std.exception;

extern(C):
nothrow:

/// Tagion c-api error codes
enum ErrorCode {
    none = 0, /// The operation completed successfully
    exception = -1, /// An exception occurred, get the exception message with tagion_error_text()
    error = -2, /// Other error
}

static Exception last_error;

/* 
  Get the error text for the last exception

  Params:
    msg = The allocated message
    msg_len = The length of the allocated message
 */
void tagion_error_text(char** msg, size_t* msg_len) {
    if (last_error) {
        *msg=cast(char*) &last_error.msg[0];
        *msg_len=last_error.msg.length;
    }
}

void tagion_clear_error() {
    last_error = null;
}

