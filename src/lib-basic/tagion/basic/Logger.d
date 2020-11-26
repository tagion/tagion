module tagion.basic.Logger;

//import core.thread;
import std.concurrency;
import core.sys.posix.pthread;
import std.string;
//import std.stdio : stderr;
import tagion.basic.Basic : Control;

extern(C) int pthread_setname_np(pthread_t, const char*) nothrow;

enum LoggerType {
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
    protected {
        string _task_name;
        uint id;
        uint[] masks;
        __gshared string logger_task_name;
    }

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
        try {
            logger_tid = locate(logger_task_name);
            .register(task_name, thisTid);
            _task_name=task_name;
            setThreadName(task_name);
            import std.stdio : stderr;

            stderr.writefln("Register: %s logger", _task_name);
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
    void report(LoggerType type, lazy string text) const nothrow {
        if ( type | masks[$-1] ) {
            import std.exception : assumeWontThrow;
            import std.conv : to;

            if (!isTask) {
                import core.stdc.stdio;
                scope const _type=assumeWontThrow(toStringz(type.to!string));
                scope const _text=assumeWontThrow(toStringz(text));
                printf("ERROR: Logger not register for '%s'", toStringz(_task_name));
                printf("\t%s:%s: %s", _task_name.toStringz, _type, _text);
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
