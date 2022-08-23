module tagion.logger.Logger;

import std.concurrency;
import core.sys.posix.pthread;
import std.string;
import std.format;

import tagion.basic.Types : Control;
import tagion.basic.TagionExceptions;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document : Document;

extern (C) int pthread_setname_np(pthread_t, const char*) nothrow;

enum LoggerType
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
        push(LoggerType.ALL);
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
    bool isTaskRegistered() const nothrow
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
    void report(LoggerType type, lazy scope string text) const nothrow
    {
        if ((type & masks[$ - 1]) && !silent)
        {
            import std.exception : assumeWontThrow;
            import std.conv : to;

            if (!isTaskRegistered)
            {
                import core.stdc.stdio;

                scope const _type = assumeWontThrow(type.to!string);
                scope const _text = assumeWontThrow(toStringz(text));
                if (_task_name.length > 0)
                {
                    printf("ERROR: Logger not register for '%.*s'\n", cast(int) _task_name.length, _task_name
                            .ptr);
                }
                printf("%.*s:%.*s: %s\n",
                    cast(int) _task_name.length, _task_name.ptr,
                    cast(int) _type.length, _type.ptr,
                    _text);
            }
            else
            {
                try
                {
                    logger_tid.send(type, _task_name, text);
                }
                catch (Exception e)
                {
                    import core.stdc.stdio;

                    scope const _type = assumeWontThrow(toStringz(type.to!string));
                    scope const _text = assumeWontThrow(toStringz(text));
                    fprintf(stderr, "\t%s:%s: %s", _task_name.toStringz, _type, _text);
                    scope const _msg = assumeWontThrow(toStringz(e.toString));
                    fprintf(stderr, "%s", _msg);
                }
            }
        }
    }

    @trusted
    void report(Args...)(LoggerType type, string fmt, lazy Args args) const nothrow
    {
        report(type, format(fmt, args));
    }

    void opCall(lazy string text) const nothrow
    {
        report(LoggerType.INFO, text);
    }

    void opCall(Args...)(string fmt, lazy Args args) const nothrow
    {
        report(LoggerType.INFO, fmt, args);
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

    private void opCall(string symbol_name, const(Document) doc, string file = __FILE__, size_t line = __LINE__) const pure nothrow
    {
        static struct LogInfo
        {
            string name;
            Document info;
            string file;
            size_t line;
            mixin HiBONRecord!(q{
                    this(string symbol_name,
                        const(Document) doc,
                        string file,
                        size_t line) {
                        this.name = symbol_name;
                        this.info = doc;
                        this.file = file;
                        this.line = line;
                    }
                });
        }

        const log_info = LogInfo(symbol_name, doc, file, line);
        /// Send log_info to the logger service
    }

    bool env(T)(
        lazy string symbol_name,
        lazy T h,
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
        report(LoggerType.TRACE, text);
    }

    void trace(Args...)(string fmt, lazy Args args) const nothrow
    {
        report(LoggerType.TRACE, fmt, args);
    }

    void warning(lazy string text) const nothrow
    {
        report(LoggerType.WARNING, text);
    }

    void warning(Args...)(string fmt, Args args) const nothrow
    {
        report(LoggerType.WARNING, fmt, args);
    }

    void error(lazy string text) const nothrow
    {
        report(LoggerType.ERROR, text);
    }

    void error(Args...)(string fmt, lazy Args args) const nothrow
    {
        report(LoggerType.ERROR, fmt, args);
    }

    void fatal(lazy string text) const nothrow
    {
        report(LoggerType.FATAL, text);
    }

    void fatal(Args...)(string fmt, lazy Args args) const nothrow
    {
        report(LoggerType.FATAL, fmt, args);
    }

    @trusted
    void close() const nothrow
    {
        if (isTaskRegistered)
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

/*
1. Format of registraton variables: logger-taskname-[list of vars]
2. Format of passing logs: task name, LogLevel(including ENV), Document(which is HiBONRecord for ENV and string for others)
3. Filter algorithm for LogFilers
4.  
*/

mixin template RegisterLogVariable(alias type, string name, string task_name = "")
{
    string generateCode()
    {
        string[] codelines;
        enum typename = type.stringof;

        // struct definition
        codelines ~= format(q{struct %s_%s_logger}, name, task_name);
        codelines ~= "{";

        // Member field
        codelines ~= format(q{private static %s _value;}, typename);

        // Getter
        codelines ~= format(q{@property static %s value()}, typename);
        codelines ~= "{";
        codelines ~= "return _value;";
        codelines ~= "}";

        // Setter with logging
        codelines ~= format(q{@property static void value(%s v)}, typename);
        codelines ~= "{";
        codelines ~= "this._value = v;";
        codelines ~= q{import std.stdio; writeln("LOOOOOOOOOOOOOOG ", _value);}; // <- HERE LOG CODE
        codelines ~= "}";

        codelines ~= "}";

        // Alias
        codelines ~= format(q{%1$s_%2$s_logger %1$s_%2$s_instance;}, name, task_name);
        codelines ~= format(q{alias %1$s = %1$s_%2$s_instance.value;}, name, task_name);

        return codelines.join('\n');
    }

    // REGISTER var in logger

    enum code = generateCode;
    pragma(msg, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    pragma(msg, code);
    pragma(msg, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    mixin(code);
}

unittest
{
    enum task = "unittest";

    /// RegisterLogVariable_int
    {
        mixin RegisterLogVariable!(int, "some_variable_int", task);

        some_variable_int = 99;
        assert(some_variable_int == 99);
    }

    /// RegisterLogVariable_string
    {
        enum s = "hello, mixin!";
        mixin RegisterLogVariable!(string, "some_variable_string", task);

        some_variable_string = s;
        assert(some_variable_string == s);
    }

    /// RegisterLogVariable_HiBON_and_Doc
    {
        import tagion.hibon.HiBON;
        import tagion.hibon.HiBONRecord;
        import tagion.hibon.Document;

        HiBON hibon = new HiBON;
        hibon["key"] = "value";

        mixin RegisterLogVariable!(HiBON, "some_variable_HiBON", task);

        some_variable_HiBON = hibon;
        assert(some_variable_HiBON == hibon);

        mixin RegisterLogVariable!(Document, "some_variable_Doc", task);

        some_variable_Doc = Document(hibon);
        assert(some_variable_Doc == Document(hibon));
    }
}
