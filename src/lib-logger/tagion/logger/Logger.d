module tagion.logger.Logger;

import std.concurrency;
import core.sys.posix.pthread;
import std.string;
import tagion.basic.Basic : Control;
import tagion.basic.TagionExceptions;
import tagion.hibon.HiBONRecord;

extern(C) int pthread_setname_np(pthread_t, const char*) nothrow;

enum LoggerType {
    NONE    = 0,
    INFO    = 1,
    TRACE   = INFO<<1,
    WARNING = TRACE<<1,
    ERROR   = WARNING <<1,
    FATAL   = ERROR<<1,
    ALL     = INFO|TRACE|WARNING|ERROR|FATAL,
    STDERR  = WARNING|ERROR|FATAL
}


private static Tid logger_tid;

@safe
static struct Logger {
    import std.format;
    protected {
        string _task_name;
        uint id;
        uint[] masks;
        __gshared string logger_task_name;

    }

    shared bool silent;

    @trusted
    static setThreadName(string name) nothrow {
        pthread_setname_np(pthread_self(), toStringz(name));
    }

    @trusted
    void register(string task_name) nothrow
        in {
            assert(logger_tid == logger_tid.init);
        }
    do {
        push(LoggerType.ALL);
        scope(exit) {
            pop;
        }
        try {
            logger_tid = locate(logger_task_name);
            .register(task_name, thisTid);
            _task_name=task_name;
            setThreadName(task_name);
            import std.stdio : stderr;

            stderr.writefln("Register: %s logger\n", _task_name);
            log("Register: %s logger", _task_name);
        }
        catch (Exception e) {
            log.error("%s logger not register", _task_name);
        }
    }

    @property @trusted
    void task_name(string task_name)
        in {
            assert(logger_tid == logger_tid.init);
        }
    do {
        _task_name=task_name;
        setThreadName(task_name);
        log("Register: %s logger", _task_name);
    }

    @trusted @nogc
    void set_logger_task(string logger_task_name) nothrow
        in {
            assert(this.logger_task_name.length == 0);
        }
    do {
        this.logger_task_name = logger_task_name;
    }

    @property @nogc
    string task_name() pure const nothrow {
        return _task_name;
    }

    @property @trusted
    bool isTask() const nothrow {
        import std.exception : assumeWontThrow;
        return assumeWontThrow(logger_tid != logger_tid.init);
    }

    void push(const uint mask) nothrow {
        masks~=mask;
    }

    @nogc
    uint pop() nothrow {
        uint result=masks[$-1];
        if ( masks.length > 1 ) {
            masks=masks[0..$-1];
        }
        return result;
    }

    @trusted
    void report(LoggerType type, lazy scope string text) const nothrow {
        if ( (type & masks[$-1]) && !silent ) {
            import std.exception : assumeWontThrow;
            import std.conv : to;

            if (!isTask) {
                import core.stdc.stdio;
                scope const _type=assumeWontThrow(type.to!string);
                scope const _text=assumeWontThrow(toStringz(text));
                if (_task_name.length > 0) {
                    printf("ERROR: Logger not register for '%.*s'\n", cast(int)_task_name.length, _task_name.ptr);
                }
                printf("%.*s:%.*s: %s\n",
                    cast(int)_task_name.length, _task_name.ptr,
                    cast(int)_type.length, _type.ptr,
                    _text);
            }
            else {
                try {
                    logger_tid.send(type, _task_name, text);
                }
                catch (Exception e) {
                    import core.stdc.stdio;
                    scope const _type=assumeWontThrow(toStringz(type.to!string));
                    scope const _text=assumeWontThrow(toStringz(text));
                    fprintf(stderr, "\t%s:%s: %s", _task_name.toStringz, _type, _text);
                    scope const _msg=assumeWontThrow(toStringz(e.toString));
                    fprintf(stderr, "%s", _msg);
                }
            }
        }
    }

    @trusted
    void report(Args...)(LoggerType type, string fmt, lazy Args args) const nothrow {
        report(type, format(fmt, args));
    }

    void opCall(lazy string text) const nothrow {
        report(LoggerType.INFO, text);
    }

    void opCall(Args...)(string fmt, lazy Args args) const nothrow {
        report(LoggerType.INFO, fmt, args);
    }


    void opCall(lazy immutable(TaskFailure) task_e) const nothrow {
        fatal("From task %s '%s'", task_e.task_name, task_e.throwable.msg);
        scope char[] text;
        const(char[]) error_text() @trusted {
            task_e.throwable.toString((buf) {text~=buf;});
            return text;
        }
        fatal("%s",  error_text());
        opCall(task_e.throwable);
    }

    @trusted
    void opCall(lazy const(Throwable) t) const nothrow {
        import std.exception;
        auto mt=assumeWontThrow(cast(Throwable)t);

        fatal(assumeWontThrow(mt.toString));
        fatal(mt.info.toString);
    }

    // void opCall(lazy const(TagionException) e) const nothrow {
    //     immutable task_e = t.taskException;
    //     if (ownerTid !=
    //     fatal("From task %s '%s'", tasg_e.task_name, e.msg);
    //     scope char[] text;
    //     const(char[]) error_text() @trusted {
    //         e.toString((buf) {text~=buf;});
    //         return text;
    //     }
    //     fatal("%s",  error_text());
    // }

    // void opCall(lazy const(Throwable) t) const nothrow if (is(T:Throwable) && !is(T:TagionExceptionInterface)) {
    //     immutable task_e = t.taskException;
    //     fatal("From task %s '%s;", tasl_e.task_name, task_e.throwable.msg);
    //     scope char[] text;
    //     const(char[]) error_text() @trusted {
    //         task_e.throwable.toString((buf) {text~=buf;});
    //         return text;
    //     }
    //     fatal("%s",  error_text());
    // }

    // void fatal(lazy const(TagionException) e) const nothrow {
    //     opCall(e);

    // }

    void trace(lazy string text) const nothrow {
        report(LoggerType.TRACE, text);
    }

    void trace(Args...)(string fmt, lazy Args args) const nothrow {
        report(LoggerType.TRACE, fmt, args);
    }

    void warning(lazy string text) const nothrow {
        report(LoggerType.WARNING, text);
    }

    void warning(Args...)(string fmt, Args args) const nothrow {
        report(LoggerType.WARNING, fmt, args);
    }

    void error(lazy string text) const nothrow {
        report(LoggerType.ERROR, text);
    }

    void error(Args...)(string fmt, lazy Args args) const nothrow {
        report(LoggerType.ERROR, fmt, args);
    }

    void fatal(lazy string text) const nothrow {
        report(LoggerType.FATAL, text);
    }

    void fatal(Args...)(string fmt, lazy Args args) const nothrow {
        report(LoggerType.FATAL, fmt, args);
    }

    @trusted
    void close() const nothrow {
        if (isTask) {
            import std.exception : assumeWontThrow;
            assumeWontThrow(logger_tid.send(Control.STOP));
        }
    }
}


static Logger log;
