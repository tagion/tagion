/// Global logger module 
module tagion.logger.Logger;

import core.sys.posix.pthread;
import std.format;
import std.string;
import tagion.basic.Types : Control;
import tagion.basic.Version : ver;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.logger.LogRecords;
import tagion.utils.pretend_safe_concurrency;

/// Is a but mask for the logger
enum LogLevel {
    NONE = 0, /// No log is e
    INFO = 1, /// Enable info logs
    TRACE = INFO << 1, /// Enable trace logs
    WARN = TRACE << 1, /// Enable warning
    ERROR = WARN << 1, /// Enable errors
    FATAL = ERROR << 1, /// Enable fatal
    ALL = INFO | TRACE | WARN | ERROR | FATAL, /// Enable all types
    STDERR = WARN | ERROR | FATAL
}

private static Tid logger_tid; /// In multi-threading mode this Tid is used

/// Logger used one for each thread
@safe
static struct Logger {

    import std.format;

    protected {
        string _task_name; /// Logger task name
        uint[] masks; /// Logger mask stack
        __gshared string logger_task_name; /// Logger task name
        __gshared Tid logger_subscription_tid;

    }

    @property
    string task_name() @nogc @safe nothrow const {
        return _task_name;
    }

    @property
    bool task_name(const string name) @safe nothrow {
        try {
            const registered = locate(name);
            const i_am_the_registered = (() @trusted => registered == thisTid)();
            if (registered is Tid.init) {

                

                    .register(name, thisTid);
                _task_name = name;
                setThreadName(name);
                return true;
            }
            else if (i_am_the_registered) {
                _task_name = name;
                return true;
            }
            else {
                return false;
            }
        }
        catch (Exception e) {
            return false;
        }
    }

    shared bool silent; /// If true the log is silened (no logs is process from any tasks)

    /**
    Register the task logger name.
    Should be done when the task starts
    */
    pragma(msg, "TODO: Remove log register when prior services are removed");
    @trusted
    void register(string task_name) nothrow
    in (logger_tid is logger_tid.init)
    do {
        push(LogLevel.ALL);
        scope (exit) {
            pop;
        }
        try {
            logger_tid = locate(logger_task_name);

            const registered = this.task_name = task_name;

            if (!registered) {
                log.error("%s logger not register", _task_name);
            }

            import std.stdio : stderr;

            static if (ver.not_unittest) {
                stderr.writefln("Register: %s logger\n", _task_name);
                log("Register: %s logger", _task_name);
            }
        }
        catch (Exception e) {
            log.error("%s logger not register", _task_name);
        }
    }

    /**
    Sets the task name of the logger for the whole program
    Note should be set in the logger task when the logger task 
is ready and has been started correctly
*/
    @trusted @nogc
    void set_logger_task(string logger_task_name) nothrow
    in {
        assert(this.logger_task_name.length == 0);
    }
    do {
        this.logger_task_name = logger_task_name;
    }

    /**
        Returns: true if the task_name has been register by the logger
    */
    @property @trusted
    bool isLoggerServiceRegistered() const nothrow {
        import std.exception : assumeWontThrow;

        return assumeWontThrow(logger_tid != logger_tid.init);
    }

    @trusted
    void registerSubscriptionTask(string task_name) {
        logger_subscription_tid = locate(task_name);
    }

    @trusted
    bool isLoggerSubRegistered() nothrow {
        return logger_subscription_tid !is Tid.init;
    }

    /**
        Push the current logger mask to the mask stack
    */
    void push(const uint mask) nothrow {
        masks ~= mask;
    }

    /**
        Pops the current logger mask
        Returns: the current mask
    */
    @nogc
    uint pop() nothrow {
        uint result = masks[$ - 1];
        if (masks.length > 1) {
            masks = masks[0 .. $ - 1];
        }
        return result;
    }

    /**
    Reports the text to the logger with the level LogLevel
    */
    @trusted
    void report(const LogLevel level, lazy scope string text) const nothrow {
        version (unittest)
            return;
        if ((masks.length > 0) && (level & masks[$ - 1]) && !silent) {
            import std.conv : to;
            import std.exception : assumeWontThrow;

            if (level & LogLevel.STDERR) {
                import core.stdc.stdio;

                scope const _level = assumeWontThrow(level.to!string);
                scope const _text = assumeWontThrow(toStringz(text));
                stderr.fprintf("%.*s:%.*s: %s\n",
                        cast(int) _task_name.length, _task_name.ptr,
                        cast(int) _level.length, _level.ptr,
                        _text);
            }

            if (!isLoggerServiceRegistered) {
                import core.stdc.stdio;

                scope const _level = assumeWontThrow(level.to!string);
                scope const _text = assumeWontThrow(toStringz(text));
                if (_task_name.length > 0) {
                    // printf("ERROR: Logger not register for '%.*s'\n", cast(int) _task_name.length, _task_name
                    //         .ptr);
                }
                printf("%.*s:%.*s: %s\n",
                        cast(int) _task_name.length, _task_name.ptr,
                        cast(int) _level.length, _level.ptr,
                        _text);
            }
            else {
                try {
                    immutable info = LogInfo(task_name, level);
                    immutable doc = TextLog(text).toDoc;
                    logger_tid.send(info, doc);
                }
                catch (Exception e) {
                    import std.stdio;

                    assumeWontThrow({ stderr.writefln("\t%s:%s: %s", task_name, level, text); stderr.writefln("%s", e); }());
                }
            }
        }
    }

    /// Conditional subscription logging
    @trusted
    void report(Topic topic, lazy string identifier, lazy const(Document) data) const nothrow {
        // report(LogLevel.INFO, "%s|%s| %s", topic.name, identifier, data.toPretty);
        if (topic.subscribed && log.isLoggerSubRegistered) {
            try {
                auto info = LogInfo(topic, task_name, identifier);
                logger_subscription_tid.send(info, data);
            }
            catch (Exception e) {
                import std.exception : assumeWontThrow;
                import std.stdio;

                assumeWontThrow({
                    stderr.writefln("%s", e.msg);
                    stderr.writefln("\t%s:%s = %s", identifier, data.toPretty);
                }());
            }
        }
    }

    void opCall(Topic topic, lazy string identifier, lazy const(Document) data) const nothrow {
        report(topic, identifier, data);
    }

    void opCall(T)(Topic topic, lazy string identifier, lazy T data) const nothrow if (isHiBONRecord!T) {
        report(topic, identifier, data.toDoc);
    }

    void opCall(Topic topic, lazy string identifier) const nothrow {
        report(topic, identifier, Document.init);
    }

    import std.traits : isBasicType;

    void opCall(T)(Topic topic, lazy string identifier, lazy T data) const nothrow if (isBasicType!T && !is(T : void)) {
        import tagion.hibon.HiBON;

        if (topic.subscribed && log.isLoggerSubRegistered) {
            try {
                auto hibon = new HiBON;
                hibon["data"] = data;
                report(topic, identifier, Document(hibon));
            }
            catch (Exception e) {
            }
        }
    }

    /**
    formatted logger 
    */
    @trusted
    void report(Args...)(LogLevel level, string fmt, lazy Args args) const nothrow {
        report(level, format(fmt, args));
    }

    /**
    logs the text to in INFO level
*/
    void opCall(lazy string text) const nothrow {
        report(LogLevel.INFO, text);
    }

    /**
logs the fmt text in INFO level
*/
    void opCall(Args...)(string fmt, lazy Args args) const nothrow {
        report(LogLevel.INFO, fmt, args);
    }

    @trusted
    void opCall(lazy const(Throwable) t) const nothrow {
        import std.exception;

        auto mt = assumeWontThrow(cast(Throwable) t);

        fatal(assumeWontThrow(mt.toString));
        fatal(mt.info.toString);
    }

    void trace(lazy string text) const nothrow {
        report(LogLevel.TRACE, text);
    }

    void trace(Args...)(string fmt, lazy Args args) const nothrow {
        report(LogLevel.TRACE, fmt, args);
    }

    void warn(lazy string text) const nothrow {
        report(LogLevel.WARN, text);
    }

    void warn(Args...)(string fmt, Args args) const nothrow {
        report(LogLevel.WARN, fmt, args);
    }

    void error(lazy string text) const nothrow {
        report(LogLevel.ERROR, text);
    }

    void error(Args...)(string fmt, lazy Args args) const nothrow {
        report(LogLevel.ERROR, fmt, args);
    }

    void fatal(lazy string text) const nothrow {
        report(LogLevel.FATAL, text);
    }

    void fatal(Args...)(string fmt, lazy Args args) const nothrow {
        report(LogLevel.FATAL, fmt, args);
    }

    @trusted
    void close() const nothrow {
        if (isLoggerServiceRegistered) {
            import std.exception : assumeWontThrow;

            assumeWontThrow(logger_tid.send(Control.STOP));
        }
    }
}

static Logger log;

import std.typecons;

@safe
struct Topic {
    string name;
    this(string name) pure nothrow {
        this.name = name;
    }

    private const(Subscribed)* _subscribed;
    private bool has_subscribed;

    @property
    bool subscribed() nothrow {
        if (!has_subscribed) {
            _subscribed = submask._register(name);
            has_subscribed = true;
        }
        if (_subscribed is null) {
            return false;
        }
        return (*_subscribed is Subscribed.yes);
    }

}

alias Subscribed = shared(Flag!"subscribed");

@safe
shared struct SubscriptionMask {
    //      yes|no     topic
    private Subscribed[string] _registered_topics;

    private const(Subscribed)* _register(string topic) nothrow {
        Subscribed* s = topic in _registered_topics;
        if (s is null) {
            _registered_topics[topic] = Subscribed.no;
            s = topic in _registered_topics;
        }
        return s;
    }

    @trusted
    void subscribe(string topic) {
        if (thisTid == log.logger_subscription_tid) {
            import std.stdio;

            writeln("SUBSCRIBED TO topic: ", topic);
            _registered_topics[topic] = Subscribed.yes;
            return;
        }
        assert(0, "Only the logger subscription task can control the subscription");
    }

    void subscribe(Topic topic) {
        subscribe(topic.name);
    }

    @trusted
    void unsubscribe(string topic) {
        if (thisTid == log.logger_subscription_tid) {
            _registered_topics[topic] = Subscribed.no;
            return;
        }
        assert(0, "Only the logger subscription task can control the subscription");
    }

    void unsubscribe(Topic topic) {
        unsubscribe(topic.name);
    }

}

static shared SubscriptionMask submask;

unittest {
    import core.time;

    Topic topic = Topic("some_tag");
    assert(!topic.subscribed, "Topic was subscribed, it shouldn't");
    register("log_sub_task", thisTid);
    log.registerSubscriptionTask("log_sub_task");
    auto some_symbol = Document.init;
    log(topic, "", some_symbol);
    assert(false == receiveTimeout(Duration.zero, (LogInfo _, const(Document) __) {}), "Received an unsubscribed topic");
    submask.subscribe(topic.name);
    assert(topic.subscribed, "Topic wasn't subscribed, it should");
    log(topic, "", some_symbol);
    assert(true == receiveTimeout(Duration.zero, (LogInfo _, const(Document) __) {}), "Didn't receive subscribed topic");
}

version (Posix) {
    import core.sys.posix.pthread;
    import std.string : toStringz;

    extern (C) int pthread_setname_np(pthread_t, const char*) nothrow;

    /**
    Set the thread name to the same as the task name
    Note. Makes it easier to debug because pthread name is the same as th task name
    */
    @trusted
    void setThreadName(string name) nothrow {
        pthread_setname_np(pthread_self(), toStringz(name));
    }
}
else {
    @trusted
    void setThreadName(string _) nothrow {
    }
}
