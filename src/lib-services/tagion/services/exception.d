/// Service Exceptions
module tagion.services.exception;

import tagion.basic.tagionexceptions;

///
@safe class ServiceException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// check function used in the HiBON package
alias check = Check!ServiceException;
