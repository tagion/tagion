module tagion.logger.Logger;

import std.concurrency;
import core.sys.posix.pthread;
import std.string;
import std.format;

import tagion.basic.Types : Control;
import tagion.basic.TagionExceptions;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONJSON;
import tagion.hibon.Document : Document;
import tagion.logger.LogRecords;

extern (C) int pthread_setname_np(pthread_t, const char*) nothrow;

enum LogLevel
{
    NONE = 0,
    INFO = 1,
    TRACE = INFO << 1,
    WARNING = TRACE << 1,
    ERROR = WARNING << 1,
    FATAL = ERROR << 1,
    ALL = INFO | TRACE | WARNING | ERROR | FATAL,
    STDERR = WARNING | ERROR | FATAL
}

private static Tid logger_tid;

@safe
static struct Logger
{

    import std.format;

    protected
    {
        string _task_name;
        uint id;
        uint[] masks;
        __gshared string logger_task_name;

    }

    shared bool silent;

    @trusted
    static setThreadName(string name) nothrow
    {
        pthread_setname_np(pthread_self(), toStringz(name));
    }

    @trusted
    void register(string task_name) nothrow
    in
    {
        assert(logger_tid == logger_tid.init);
    }
    do
    {
        push(LogLevel.ALL);
        scope (exit)
        {
            pop;
        }
        try
        {
            logger_tid = locate(logger_task_name);

            

            .register(task_name, thisTid);
            _task_name = task_name;
            setThreadName(task_name);
            import std.stdio : stderr;

            stderr.writefln("Register: %s logger\n", _task_name);
            log("Register: %s logger", _task_name);
        }
        catch (Exception e)
        {
            log.error("%s logger not register", _task_name);
        }
    }

    @property @trusted
    void task_name(string task_name)
    in
    {
        assert(logger_tid == logger_tid.init);
    }
    do
    {
        _task_name = task_name;
        setThreadName(task_name);
        log("Register: %s logger", _task_name);
    }

    @trusted @nogc
    void set_logger_task(string logger_task_name) nothrow
    in
    {
        assert(this.logger_task_name.length == 0);
    }
    do
    {
        this.logger_task_name = logger_task_name;
    }

    @property @nogc
    string task_name() pure const nothrow
    {
        return _task_name;
    }

    @property @trusted
    bool isLoggerServiceRegistered() const nothrow
    {
        import std.exception : assumeWontThrow;

        return assumeWontThrow(logger_tid != logger_tid.init);
    }

    void push(const uint mask) nothrow
    {
        masks ~= mask;
    }

    @nogc
    uint pop() nothrow
    {
        uint result = masks[$ - 1];
        if (masks.length > 1)
        {
            masks = masks[0 .. $ - 1];
        }
        return result;
    }

    @trusted
    void report(LogLevel level, lazy scope string text) const nothrow
    {
        if ((level & masks[$ - 1]) && !silent)
        {
            import std.exception : assumeWontThrow;
            import std.conv : to;

            if (!isLoggerServiceRegistered)
            {
                import core.stdc.stdio;

                scope const _level = assumeWontThrow(level.to!string);
                scope const _text = assumeWontThrow(toStringz(text));
                if (_task_name.length > 0)
                {
                    printf("ERROR: Logger not register for '%.*s'\n", cast(int) _task_name.length, _task_name
                            .ptr);
                }
                printf("%.*s:%.*s: %s\n",
                    cast(int) _task_name.length, _task_name.ptr,
                    cast(int) _level.length, _level.ptr,
                    _text);
            }
            else
            {
                try
                {
                    immutable filter = LogFilter(_task_name, level);
                    immutable doc = TextLog(text).toDoc;
                    logger_tid.send(filter, doc);
                }
                catch (Exception e)
                {
                    import core.stdc.stdio;

                    scope const _level = assumeWontThrow(toStringz(level.to!string));
                    scope const _text = assumeWontThrow(toStringz(text));
                    fprintf(stderr, "\t%s:%s: %s", _task_name.toStringz, _level, _text);
                    scope const _msg = assumeWontThrow(toStringz(e.toString));
                    fprintf(stderr, "%s", _msg);
                }
            }
        }
    }

    @trusted
    void report(T)(string symbol_name, T h) const nothrow if (isHiBONRecord!T)
    {
        import std.exception : assumeWontThrow;

        if (isLoggerServiceRegistered)
        {
            try
            {
                logger_tid.send(LogFilter(_task_name, symbol_name), h.toDoc);
            }
            catch (Exception e)
            {
                import core.stdc.stdio;

                scope const _symbol_name = assumeWontThrow(toStringz(symbol_name));
                fprintf(stderr, "\t%s:%s env", _task_name.toStringz, _symbol_name);
                scope const _msg = assumeWontThrow(toStringz(e.toString));
                fprintf(stderr, "%s", _msg);
            }
        }
    }

    @trusted
    void report(Args...)(LogLevel level, string fmt, lazy Args args) const nothrow
    {
        report(level, format(fmt, args));
    }

    void opCall(lazy string text) const nothrow
    {
        report(LogLevel.INFO, text);
    }

    void opCall(Args...)(string fmt, lazy Args args) const nothrow
    {
        report(LogLevel.INFO, fmt, args);
    }

    void opCall(lazy immutable(TaskFailure) task_e) const nothrow
    {
        fatal("From task %s '%s'", task_e.task_name, task_e.throwable.msg);
        scope char[] text;
        const(char[]) error_text() @trusted
        {
            task_e.throwable.toString((buf) { text ~= buf; });
            return text;
        }

        fatal("%s", error_text());
        opCall(task_e.throwable);
    }

    bool env(T)(
        string symbol_name,
        T h,
        string file = __FILE__,
        size_t line = __LINE__) nothrow if (isHiBONRecord!T)
    {
        static bool registered;
        if (!registered)
        {
            // Register the task name and the symbol_name
        }
        /+
        if (is the filter set for this symbol the call the opCall) {
        opCall(symbol_name, h.toDoc, file, line);
        }
        +/
        report(symbol_name, h);

        return registered;
    }

    @trusted
    void opCall(lazy const(Throwable) t) const nothrow
    {
        import std.exception;

        auto mt = assumeWontThrow(cast(Throwable) t);

        fatal(assumeWontThrow(mt.toString));
        fatal(mt.info.toString);
    }

    void trace(lazy string text) const nothrow
    {
        report(LogLevel.TRACE, text);
    }

    void trace(Args...)(string fmt, lazy Args args) const nothrow
    {
        report(LogLevel.TRACE, fmt, args);
    }

    void warning(lazy string text) const nothrow
    {
        report(LogLevel.WARNING, text);
    }

    void warning(Args...)(string fmt, Args args) const nothrow
    {
        report(LogLevel.WARNING, fmt, args);
    }

    void error(lazy string text) const nothrow
    {
        report(LogLevel.ERROR, text);
    }

    void error(Args...)(string fmt, lazy Args args) const nothrow
    {
        report(LogLevel.ERROR, fmt, args);
    }

    void fatal(lazy string text) const nothrow
    {
        report(LogLevel.FATAL, text);
    }

    void fatal(Args...)(string fmt, lazy Args args) const nothrow
    {
        report(LogLevel.FATAL, fmt, args);
    }

    @trusted
    void close() const nothrow
    {
        if (isLoggerServiceRegistered)
        {
            import std.exception : assumeWontThrow;

            assumeWontThrow(logger_tid.send(Control.STOP));
        }
    }
}

mixin template Log(alias name)
{
    pragma(msg, name.stringof);
    pragma(msg, "__traits ", __traits(identifier, name));
    pragma(msg, format(q{const bool %1$s_logger = log.env("%1$s", %1$s);}, __traits(identifier, name)));
    mixin(format(q{const bool %1$s_logger = log.env("%1$s", %1$s);}, __traits(identifier, name))); //format(q{const bool %1$s_logger = log("%1$s", %1$s);}, name.stringof));
    // enum logged_code = format!(
    //     q{bool %s_logged =
    //             log(name.stringof, name);},
    //     name.stringof);
    //    const x=log(name.stringof, name);
    // pragma(msg, logged_code);
    // mixin(logged_code);

}

static Logger log;

unittest
{
    import tagion.hibon.HiBONRecord;

    static struct S
    {
        int x;
        mixin HiBONRecord!(
            q{this(int x) {this.x = x;}}
        );
    }

    const s = S(10);
    mixin Log!s;

}
