module hibon.utils.Bailout;


extern(C):
@nogc:
import core.stdc.string;
import core.stdc.stdio;
import hibon.utils.Text;

enum MESSAGE_BUFFER_SIZE=0x80;

protected __gshared const(char)[] _message;
protected __gshared char[MESSAGE_BUFFER_SIZE] _message_buffer;
protected __gshared size_t _line;
protected __gshared const(char)[] _file;

const(char[]) message(Args...)(string text, Args args) {
    auto temp=Text(_message_buffer.length);
//    temp(text);
//    snprintf(_message_buffer.ptr, _message_buffer.length, text.ptr, args[0]);
//      version(none)
    enum {
        NUM="%d",
        TEXT="%s"
    }
    size_t pos;
    static foreach(arg; args) {
        {
            const start=pos;
            while (pos+NUM.length < text.length){
                if ((text[pos..pos+NUM.length] == NUM || text[pos..pos+TEXT.length] == TEXT)) {
                    temp(text[start..pos])(arg);
                    break;
                }
                pos++;
            }
        }
    }
    _message_buffer[0..temp.length]=temp.serialize;
    _message_buffer[temp.length]='\0';
//    _message=_message_buffer;
    return _message_buffer;
}

unittest {
    auto test=message("text=%d", 10);
}

void check(const bool flag, lazy const(char[]) msg,  string file = __FILE__, size_t line = __LINE__) {
    if ((!flag) && (_message is null)) {
        _message=msg;
        _file=file;
        _line=line;
    }
}

void clear() {
    _message=null;
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

void dump() {
    if (message) {
        printf("%s:%s:%s\n", file.ptr, line, message.ptr);
    }
    else {
        printf("No error\n");
    }
}
