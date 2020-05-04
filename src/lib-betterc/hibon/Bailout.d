module hibon.Bailout;


extern(C):
import core.stdc.string;
import core.stdc.stdio;

enum MESSAGE_BUFFER_SIZE=0x80;

protected __gshared const(char)[] _message;
protected __gshared char[MESSAGE_BUFFER_SIZE] _message_buffer;

const(char[]) message(T1)(string text, T1 arg1) {
    _message_buffer[0..text.length]=text;
//    printf(_message_buffer.ptr, arg1);
//    snprintf(_message_buffer.ptr, _message_buffer.length, _message_buffer.ptr, arg1);
    return _message[0..strlen(_message_buffer.ptr)];
}


const(char[]) message(T1, T2)(string text, T1 arg1, T2 arg2 ) {
    _message_buffer[0..text.length]=text;
//    printf(_message_buffer.ptr, arg1, arg2);
//    snprintf(_message_buffer.ptr, _message_buffer.length, _message_buffer.ptr, arg1, arg2);
    return _message[0..strlen(_message_buffer.ptr)];
}


const(char[]) message(T1, T2, T3)(string text, T1 arg1, T2 arg2, T3 arg3) {
    _message_buffer[0..text.length]=text;
//    printf(_message_buffer.ptr, arg1, arg2, arg3);

    snprintf(_message_buffer.ptr, _message_buffer.length, _message_buffer.ptr, arg1, arg2, arg3);
    return _message[0..strlen(_message_buffer.ptr)];
}


unittest {
    auto test=message("text=%d", 10);
}

void check(const bool flag, lazy const(char[]) msg) {
    if (!flag && (_message is null)) {
        _message=msg;
    }
}

void clear() {
    _message=null;
}

bool failed() {
    return _message !is null;
}
