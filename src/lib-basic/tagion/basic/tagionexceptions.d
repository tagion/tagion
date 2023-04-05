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
    //    string task_name; /// Contains the name of the task when the execption has throw
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow {
        super(msg, file, line);
    }
}

/++
 + Builds a check function out of a TagionExecption
 +/
@safe
void Check(E)(bool flag, lazy string msg, string file = __FILE__, size_t line = __LINE__) pure {
    static assert(is(E : TagionExceptionInterface));
    if (!flag) {
        throw new E(msg, file, line);
    }
}

struct TaskFailure {
    Throwable throwable;
    string task_name;
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

    return immutable(TaskFailure)(cast(immutable) e, log.task_name);
}

@safe
static void fatal(const(Throwable) e) nothrow {
    import tagion.logger.Logger;

    immutable task_e = taskException(e);
    log(task_e);
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
