module tagion.tools.toolsexception;

import tagion.errors.tagionexceptions;

/**
 * Exception type used by tagion.tools module
 */
@safe class ToolsException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

/// check function used in the HiBON package
alias check = Check!(ToolsException);
