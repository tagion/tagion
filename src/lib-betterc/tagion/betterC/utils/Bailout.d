/// \file Bailout.d

module tagion.betterC.utils.Bailout;

@nogc:
import tagion.betterC.utils.platform;

// import core.stdc.string;
// import core.stdc.stdio;
import tagion.betterC.utils.Text;

enum MESSAGE_BUFFER_SIZE = 0x80;

protected __gshared const(char)[] _message;
protected __gshared char[MESSAGE_BUFFER_SIZE] _message_buffer;
protected __gshared size_t _line;
protected __gshared const(char)[] _file;

/**
 * @brief File created for providing base functionality for messages
 */

/**
 * Function create buffer based on unout string with data and arguments
 * @param text - input data
 * @param args - arguments which can be set for every message
 * @return buffer based on input data and arguments
 */

bool isEqual(immutable(char)[] input_arr, string word, size_t start_pos) {
    bool res = true;
    foreach (i, key; word) {
        if (input_arr[start_pos + i] != key) {
            res = false;
            break;
        }
    }
    return res;
}

const(char[]) message(Args...)(string text, Args args) {
    auto temp = Text(_message_buffer.length);
    enum {
        NUM = "%d",
        TEXT = "%s"
    }
    size_t pos;
    static foreach (arg; args) {
        {
            const start = pos;
            while (pos + NUM.length < text.length) {
                if (isEqual(text, NUM, pos) || isEqual(text, TEXT, pos)) {
                    temp(text[start .. pos])(arg);
                    break;
                }
                pos++;
            }
        }
    }
    _message_buffer[0 .. temp.length] = temp.serialize;
    _message_buffer[temp.length] = '\0';
    //    _message=_message_buffer;
    return _message_buffer;
}

unittest {
    auto test = message("text=%d", 10);
}

void check(const bool flag, lazy const(char[]) msg, string file = __FILE__, size_t line = __LINE__) {
    if ((!flag) && (_message is null)) {
        _message = msg;
        _file = file;
        _line = line;
    }
}

void clear() {
    _message = null;
}

bool failed() {
    return _message !is null;
}

const(char[]) message() {
    return _message;
}

size_t line() {
    return _line;
}

const(char[]) file() {
    return _file;
}

version (WebAssembly) {
    void dump() {
        // empty
    }
}
else {
    void dump() {
        if (message) {
            printf("%s:%d:%s\n", file.ptr, cast(int) line, message.ptr);
        }
        else {
            printf("No error\n");
        }
    }
}
