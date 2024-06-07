module tagion.basic.tagionexceptions;

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
    //    string task_name; /// Contains the name of the task when the exception has throw
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

/++
 + Builds a check function out of a TagionException
 +/
@safe
void Check(E)(bool flag, lazy string msg, string file = __FILE__, size_t line = __LINE__) pure {
    static assert(is(E : TagionExceptionInterface));
    if (!flag) {
        throw new E(msg, file, line);
    }
}
