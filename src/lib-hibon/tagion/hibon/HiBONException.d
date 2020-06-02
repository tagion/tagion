module tagion.hibon.HiBONException;


import tagion.basic.TagionExceptions;
/++
 Exception type used by tagion.hibon.HiBON module
 +/
@safe
class HiBONExceptionT(bool LOGGER) : TagionExceptionT!LOGGER {
    static if (LOGGER) {
        this(string msg, string task_name="undefined", string file = __FILE__, size_t line = __LINE__ ) pure {
            super( msg, task_name, file, line );
        }
    }
    else {
        this(string msg, string file = __FILE__, size_t line = __LINE__ ) {
            super( msg, file, line );
        }
    }
}

alias HiBONException=HiBONExceptionT!false;

/// check function used in the HiBON package
alias check=Check!(HiBONException);
