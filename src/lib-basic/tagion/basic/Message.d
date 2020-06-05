module tagion.basic.Message;

import std.format;
import std.json;

//import tagion.Options;

static string language="";
version(UPDATE_MESSAGE_TABEL) {
    @safe synchronized struct Message {
        private static shared string[string] translation;
        static JSONValue toJSON() {
            //JSONValue language;
            result[language.stringof]="en";
            JSONValue tabel;
            foreach(from, to; tabel) {
                tabel[from]=to;
            }
            result[translation.stringof]=tabel;
        }
    }
}
else {
    private static __gshared string[string] __translation;
    static immutable(string[string]*) translation;
    shared static this() {
        translation=cast(immutable)(&__translation);
    }
    synchronized struct Message {
        static void set(string from, string to) {
            __translation[from]=to;
        }
        static void load(JSONValue json) {
            auto trans=json[translation.stringof].object;
            foreach(from, to; trans) {
                __translation[from]=to.str;
            }
        }
    }
}

@trusted
string message(Args...)(string fmt, lazy Args args) {
    if (language == "" ) {
        version(UPDATE_MESSAGE_TABEL) {
            if (!(fmt in translation)) {
                Message.set(fmt,fmt);
            }
        }
        return format(fmt, args);
    }
    else {
        immutable translate_fmt=translation.get(fmt, fmt);
        return format(translate_fmt, args);
    }
}
