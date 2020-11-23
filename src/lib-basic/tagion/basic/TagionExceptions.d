module tagion.basic.TagionExceptions;

import std.exception;

@safe
interface TagionExceptionInterface {
// Empty
}

/++
 + Exception used as a base exception class for all exceptions use in tagion project
 +/
@safe
class TagionException : Exception, TagionExceptionInterface {
    string task_name; /// Contains the name of the task when the execption has throw
    this(string msg, string file = __FILE__, size_t line = __LINE__ ) pure nothrow {
        super( msg, file, line );
    }

    /++
     This function set the taskname set by the logger
     The version LOGGER must be enabled for this to work
     The function is used to send the exception to the task owner ownerTid
     Returns:
     The immutable version of the Exception
     +/
    @trusted
    final immutable(TagionException) taskException() {
        version(LOGGER) {
            import tagion.services.LoggerService;
            if (task_name.length > 0) {
                task_name=log.task_name;
            }
        }
        return cast(immutable)this;
    }
}

/++
 + Builds a check function out of a TagionExecption
 +/
@safe
void Check(E)(bool flag, lazy string msg, string file = __FILE__, size_t line = __LINE__) pure {
    static assert(is(E:TagionExceptionInterface));
    if (!flag) {
        throw new E(msg, file, line);
    }
}
