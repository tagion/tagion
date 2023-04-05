module tagion.new_services.ServiceException;

import tagion.basic.tagionexceptions;

/++
 Exception type used by tagion.hibon.HiBON module
 +/
@safe class ServiceException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

/// check function used in the HiBON package
alias check = Check!(ServiceException);
