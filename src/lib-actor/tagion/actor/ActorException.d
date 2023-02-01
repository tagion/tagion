module tagion.actor.ActorException;

import tagion.basic.TagionExceptions;

/++
 Exception type used by tagion.actor package
 +/
@safe class ActorException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

/// check function used in the actor package
alias check = Check!(ActorException);
