module tagion.hibon.HiBONException;
//import tagion.TagionExceptions : Check, TagionException;

import std.exception;
/++
 Exception type used by tagion.hibon.HiBON module
 +/

class BeterC_HiBONException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line );
    }
}

/// check function used in the HiBON package
void check(const bool flag, string msg, string file = __FILE__, size_t line = __LINE__) {
    if (!flag) {
        throw new HiBONException(msg, file, line);
    }
}
