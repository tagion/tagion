module tagion.behaviour.BehaviourException;

import tagion.basic.TagionExceptions;
import tagion.hibon.HiBONRecord;
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

struct BehaviourError {
    string msg;
    string[] trace;
    mixin HiBONRecord!(q{
            this(Exception e) {
                import std.string : splitLines;
                msg=e.msg;
                trace=e.toString.splitLines;
            }
        });


}
