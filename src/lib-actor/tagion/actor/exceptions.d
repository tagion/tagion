module tagion.actor.exceptions;

import std.traits;
import std.exception;
import std.format;
import std.conv;

import tagion.basic.tagionexceptions : TagionException;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBON;
import tagion.hibon.Document;

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

    this(string task_name, const(Throwable) e) @trusted pure nothrow {
        task_name =task_name;
        throwable = cast(immutable) e;
    }

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

unittest {
    auto e = new RunFailure("this is a unittest");
    immutable tf = TaskFailure("some_task", e);
    tf.toDoc;
    tf.toString;
}
