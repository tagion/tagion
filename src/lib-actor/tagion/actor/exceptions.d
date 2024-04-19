module tagion.actor.exceptions;

import std.traits;
import std.exception;
import std.format;
import tagion.basic.tagionexceptions : TagionException;

import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBON;
import tagion.hibon.Document;
import std.conv;

// Fake Throwable hibon record constructor
@recordType("throwable")
struct _Throwable {
    string msg;
    string file;
    ulong line;
    string trace;
    mixin HiBONRecord!(q{
        this(const Throwable t) @trusted {
            msg = t.msg;
            file = t.file;
            line = t.line;
            trace = t.info.to!string;
        }
    });
}

immutable struct TaskFailure {
    string task_name;
    Throwable throwable;

    const(Document) toDoc() @safe const {
        auto hibon = new HiBON;
        hibon[(GetLabel!task_name).name] = task_name;
        hibon[(GetLabel!throwable).name] = _Throwable(throwable).toDoc;
        return Document(hibon);
    }

    string toString() const nothrow {
        return assumeWontThrow(format!"FROM(%s): %s"(task_name, throwable));
    }
}

/++
 This function set the taskname set by the logger
 The version LOGGER must be enabled for this to work
 The function is used to send the exception to the task owner ownerTid
 Returns:
 The immutable version of the Exception
 +/
@trusted
static immutable(TaskFailure) taskException(const(Throwable) e) nothrow { //if (is(T:Throwable) && !is(T:TagionExceptionInterface)) {
    import tagion.logger.Logger;

    return immutable(TaskFailure)(log.task_name, cast(immutable) e);
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
