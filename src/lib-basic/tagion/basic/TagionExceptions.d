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
//    string task_name; /// Contains the name of the task when the execption has throw
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
    version(none)
    @trusted
    final immutable(TaskException) taskException() {
        // version(LOGGER) {
        import tagion.basic.Logger;
        // if (task_name.length > 0) {
        //     task_name=log.task_name;
        // }
        // }
        return immutable(TaskException)(cast(immutable)this, log.task_name);
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
static immutable(TaskFailure) taskException(const(Throwable) e) nothrow  { //if (is(T:Throwable) && !is(T:TagionExceptionInterface)) {
    import tagion.basic.Logger;
    return immutable(TaskFailure)(cast(immutable)e, log.task_name);
}

static void fatal(const(Throwable) e) nothrow {
    import tagion.basic.Logger;
    import std.concurrency;
    immutable task_e = taskException(e);
    log(task_e);
    try {
        if (ownerTid != Tid.init) {
            ownerTid.send(task_e);
        }
    }
    catch (Exception e) {
        log.fatal(e.msg);
    }
}


static void taskfailure(immutable(TaskFailure) t) {
    import std.concurrency;
    ownerTid.send(t);
}
