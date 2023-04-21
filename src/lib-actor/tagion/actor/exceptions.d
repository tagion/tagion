module tagion.actor.exceptions;

import tagion.basic.tagionexceptions : TagionException, TaskFailure, Check;

/**
 Exception type used by tagion.actor.actor
 */
@safe class ActorException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// Exception sent when the actor gets a message that it doesn't handle
@safe class UnknownMessage : ActorException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

// Exception when the actor fails to start or stop
@safe class RunFailure : ActorException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// Exception sent when the actor gets a message that it doesn't handle
@safe class MessageTimeout : ActorException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

/// check function used in the behaviour package
alias check = Check!(ActorException);
