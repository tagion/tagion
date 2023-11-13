module tagion.script.ScriptException;

import tagion.basic.tagionexceptions : Check, TagionException;

/**
 * Exception type used in the Script package
 */
@safe
class ScriptException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

/// check function used in the Script package
alias check = Check!(ScriptException);
