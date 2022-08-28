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

@safe
@RecordType("BDDError")
struct BehaviourError {
    string msg;
    string[] trace;
    mixin HiBONRecord!(q{
            this(Exception e) nothrow @trusted {
                import std.exception : assumeWontThrow;
                import std.string : splitLines;
                import std.stdio;
                msg =e.msg;
                trace= assumeWontThrow(e.toString.splitLines);
            }
        });
}

@safe
@RecordType("BDDResult")
struct Result {
    import tagion.hibon.Document;
//    int x;
    Document result;
    mixin HiBONRecord!();
}
