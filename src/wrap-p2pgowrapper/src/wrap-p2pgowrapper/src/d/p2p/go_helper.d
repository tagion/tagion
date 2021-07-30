module p2p.go_helper;

import p2p.lib.helper;
import p2p.lib.libp2p;
import std.conv;

DBuffer ToDString(ref string str) {
    DBuffer dstr = {pointer: cast(char*)(str.ptr), length: cast(int) str.length};
    return dstr;
}

string ToString(ref DBuffer dstr) {
    return (cast(char*) dstr.pointer)[0 .. dstr.length].idup;
}

GoSlice ToGoSlice(T)(ref T[] arr) {
    GoSlice gs = {data: arr.ptr, len: arr.length, cap: arr.capacity};
    return gs;
}

auto cgocheck(T)(T response) {
    static if (is(T == ErrorCode)) {
        auto code = cast(ErrorCode) response;
        if (code != ErrorCode.Ok) {
            throw new GoException(code);
        }
    }
    else {
        static assert(response.tupleof.length >= 2);
        static assert(is(typeof(response.tupleof[$ - 1]) == ErrorCode));
        response.tupleof[$ - 1].cgocheck;
        static if (response.tupleof.length == 2) {
            return response.tupleof[0];
        }
        else {
            return response;
        }
    }
}

class GoException : Exception {
    ErrorCode Code;

    this(ErrorCode code, string file = __FILE__, size_t line = __LINE__) {
        Code = code;
        super(to!string(code), file, line);
    }
}
