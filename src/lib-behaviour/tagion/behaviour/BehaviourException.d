module tagion.behaviour.BehaviourException;

import tagion.basic.TagionExceptions;

/++
 Exception type used by tagion.hibon.HiBON module
 +/
@safe class BehaviourException : TagionException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure
    {
        super(msg, file, line);
    }
}

/// check function used in the HiBON package
alias check = Check!(BehaviourException);
