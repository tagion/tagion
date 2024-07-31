module tagion.api.errors;

nothrow:

package
void last_error(const Exception e) {
    last_error_text = e.msg;
}

package
void set_error_text(string msg) {
    last_error_text = msg;
}

/* static Exception last_error; */
private
string last_error_text;

extern(C):

/// Tagion c-api error codes
enum ErrorCode {
    none = 0, /// The operation completed successfully
    exception = -1, /// An exception occurred, get the exception message with tagion_error_text()
    error = -2, /// Other error
}


/* 
  Get the error text for the last exception

  Params:
    msg = The allocated message
    msg_len = The length of the allocated message
 */
void tagion_error_text(char** msg, size_t* msg_len) {
    *msg_len = 0;
    if (last_error_text) {
        *msg=cast(char*) &last_error_text[0];
        *msg_len=last_error_text.length;
    }
}

unittest {
    char* msg_ptr = new char*;
    size_t msg_len;
    last_error = new Exception("bad exception");
    tagion_error_text(&msg_ptr, &msg_len);
    assert(msg_ptr[0..msg_len] == "bad exception");

    last_error_text = "bad error";
    tagion_error_text(&msg_ptr, &msg_len);
    assert(msg_ptr[0..msg_len] == "bad error");

    tagion_clear_error();
    tagion_error_text(&msg_ptr, &msg_len);
    assert(msg_len == 0);
}

void tagion_clear_error() {
    last_error_text = "";
    /* last_error = null; */
}
