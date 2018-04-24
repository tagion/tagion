module tagion.Base;

import tagion.crypto.Hash;
import std.string : format;

enum this_dot="this.";

import std.conv;
/**
   Return the position of first '.' in string and
 */
template find_dot(string str, size_t index=0) {
    static if ( index >= str.length ) {
        enum zero_index=0;
        alias zero_index find_dot;
    }
    else static if (str[index] == '.') {
        enum index_plus_one=index+1;
        static assert(index_plus_one < str.length, "Static name ends with a dot");
        alias index_plus_one find_dot;
    }
    else {
        alias find_dot!(str, index+1) find_dot;
    }
}

/**
   Template function for removing the "this." prefix
 */
template basename(alias K) {
    enum name=K.stringof;
    static if (
        (name.length > this_dot.length) &&
        (name[0..this_dot.length] == this_dot) ) {
        alias name[this_dot.length..$] basename;
    }
    else {
        enum dot_pos=find_dot!(name);
        static if ( dot_pos > 0 ) {
            enum suffix=name[dot_pos..$];
            alias suffix basename;
        }
        else {
            alias name basename;
        }
    }
}

unittest {
    enum name_another="another";
    struct Something {
        mixin("int "~name_another~";");
        void check() {
            assert(find_dot!(this.another.stringof) == this_dot.length);
            assert(basename!(this.another) == name_another);
        }
    }
    Something something;
    static assert(find_dot!((something.another).stringof) == something.stringof.length+1);
    static assert(basename!(something.another) == name_another);
    something.check();
}

template EnumText(string name, string[] list, bool first=true) {
    static if ( first ) {
        enum begin="enum "~name~"{";
        alias EnumText!(begin, list, false) EnumText;
    }
    else static if ( list.length > 0 ) {
        enum k=list[0];
        enum code=name~k~" = "~'"'~k~'"'~',';
        alias EnumText!(code, list[1..$], false) EnumText;
    }
    else {
        enum code=name~"}";
        alias code EnumText;
    }
}

unittest {
    enum list=["red", "green", "blue"];
//    pragma(msg, EnumText!("Colour", list));
    mixin(EnumText!("Colour", list));
    static assert(Colour.red == list[0]);
    static assert(Colour.green == list[1]);
    static assert(Colour.blue == list[2]);

}
enum ThreadState {
    KILL = 9,
    LIVE = 1
}

@safe
immutable(Hash) hfuncSHA256(immutable(ubyte)[] data) {
    import tagion.crypto.SHA256;
    return SHA256(data);
}


