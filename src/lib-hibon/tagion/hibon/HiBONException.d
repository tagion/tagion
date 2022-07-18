module tagion.hibon.HiBONException;

import tagion.basic.TagionExceptions;

/++
 Exception type used by tagion.hibon.HiBON module
 +/
@safe class HiBONException : TagionException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure
    {
        super(msg, file, line);
    }
}

/// check function used in the HiBON package
alias check = Check!(HiBONException);

@safe class HiBONRecordException : HiBONException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure
    {
        super(msg, file, line);
    }
}
