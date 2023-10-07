module tagion.actor.exceptions;

import tagion.basic.tagionexceptions : TagionException;
import std.exception;

immutable struct TaskFailure {
    string task_name;
    Throwable throwable;
}

/++
 This function set the taskname set by the logger
 The version LOGGER must be enabled for this to work
 The function is used to send the exception to the task owner ownerTid
 Returns:
 The immutable version of the Exception
 +/
@trusted
static immutable(TaskFailure) taskException(const(Throwable) e) @nogc nothrow { //if (is(T:Throwable) && !is(T:TagionExceptionInterface)) {
    import tagion.logger.Logger;

    return immutable(TaskFailure)(log.task_name, cast(immutable) e);
}

@safe
static void fatal(const(Throwable) e) nothrow {
    import tagion.logger.Logger;

    immutable task_e = taskException(e);
    log(task_e.throwable);
    try {
        task_e.taskfailure;
    }
    catch (Exception t) {
        log.fatal(t.msg);
    }
}

@trusted
static void taskfailure(immutable(TaskFailure) t) nothrow {
    import std.concurrency;

    assumeWontThrow({
        if (ownerTid != Tid.init) {
            ownerTid.send(t);
        }
    });
}

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
