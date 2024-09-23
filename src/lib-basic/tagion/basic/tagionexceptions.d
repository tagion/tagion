module tagion.basic.tagionexceptions;

import std.exception;

enum ERRORS {
    HIBON = 10_000, 
    HASHGRAPH = 11_000,
    GOSSIPNET = 12_000,
    DART = 13_000,
    SECURITY = 14_000,
    CIPHER = 15_000,
    CREDITIAL = 16_000,
    NETWORK = 17_000,
    TVM = 18_000,
    
    
}

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
