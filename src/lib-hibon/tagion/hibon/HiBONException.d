module tagion.hibon.HiBONException;

import tagion.basic.tagionexceptions;

@safe:
/++
 Exception type used by tagion.hibon.HiBON module
 +/
class HiBONException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

alias check = Check!HiBONException;

class HiBONRecordException : HiBONException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

class HiBONRecordTypeException : HiBONRecordException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}
