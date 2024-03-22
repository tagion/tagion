/// Service Exceptions
module tagion.services.exception;

import tagion.basic.tagionexceptions;

/// tagion service exceptions
@safe class ServiceException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// Unrecoverable tagion service error
@safe class ServiceError : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// check function used in the HiBON package
alias check = Check!ServiceException;
