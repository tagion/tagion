/// Global logger module 
module tagion.logger.Logger;

import core.sys.posix.pthread;
import std.format;
import std.string;
import std.stdio;

import tagion.basic.Version : ver;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.logger.LogRecords;
import tagion.logger.writer;
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
private static Tid logger_subscription_tid;


/// Logger used one for each thread
@safe
static struct Logger {

    import std.format;

    protected {
        string _task_name; /// The name of the task using the logger
        uint[] masks; /// Logger mask stack
        __gshared string logger_task_name; /// Logger task name
        __gshared string logger_subscription_task_name;
    }

    /// Get task_name
    @property
    string task_name() @nogc @safe nothrow const {
        return _task_name;
    }

    /* 
     * Sets the actor/log task_name
     * Returns: false the task_name could not be set
     */
    @property
    bool task_name(const string name) @safe nothrow {
        push(LogLevel.ALL);
        scope (exit) {
            pop();
        }
        try {
            locateLoggerTask();

            const registered = locate(name);
            const i_am_the_registered = registered is thisTid;
            if (registered is Tid.init) {
                register(name, thisTid);
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
    Sets the task name of the logger for the whole program
    Note should be set in the logger task when the logger task 
is ready and has been started correctly
*/
    @trusted @nogc
    void set_logger_task(string logger_task_name) nothrow
    in (this.logger_task_name.length == 0, "Logger task name is already set")
    do {
        this.logger_task_name = logger_task_name;
    }

    /**
        Returns: true if the task_name has been register by the logger
    */
    @safe
    bool isLoggerServiceRegistered() const nothrow {
        return logger_tid !is Tid.init;
    }

    private void locateLoggerTask() @trusted const {
        if (!isLoggerServiceRegistered) {
            logger_tid = locate(logger_task_name);
        }
    }

    @trusted
    void registerSubscriptionTask(string task_name) {
        logger_subscription_task_name = task_name;
        locateLoggerSubscriptionTask();
    }

    bool isLoggerSubRegistered() const nothrow {
        return logger_subscription_tid !is Tid.init;
    }

    private void locateLoggerSubscriptionTask() @trusted const nothrow {
        if (!isLoggerSubRegistered) {
            logger_subscription_tid = locate(logger_subscription_task_name);
        }
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
    version (LogWriter) {
        void report(const LogLevel level, lazy scope string text) const nothrow {
            import std.exception : assumeWontThrow;

            version (unittest)
                return;
            if ((masks.length > 0) && (level & masks[$ - 1]) && !silent) {
                immutable info = LogInfo(task_name, level);

                if (isLoggerServiceRegistered) {
                    try {
                        immutable textlog = TextLog(text);
                        logger_tid.send(info, textlog.toDoc);
                    }
                    catch (Exception e) {
                        LogWriter.stdoutwrite(info, assumeWontThrow(text));
                        LogWriter.stdoutwrite(info, e.message);
                    }
                }
                else {
                    LogWriter.stdoutwrite(info, assumeWontThrow(text));
                }
            }
            return;
        }
    }
    else {
        void report(const LogLevel level, lazy scope string text) const nothrow @trusted {
            import std.exception : assumeWontThrow;

            version (unittest)
                return;
            if ((masks.length > 0) && (level & masks[$ - 1]) && !silent) {
                import std.conv : to;

                if (level & LogLevel.STDERR) {
                    import core.stdc.stdio;

                    scope const _level = assumeWontThrow(level.to!string);
                    scope const _text = toStringz(assumeWontThrow(text));
                    stderr.fprintf("%.*s:%.*s: %s\n",
                        cast(int) _task_name.length, _task_name.ptr,
                        cast(int) _level.length, _level.ptr,
                        _text);
                }

                if (!isLoggerServiceRegistered) {
                    import core.stdc.stdio;

                    scope const _level = assumeWontThrow(level.to!string);
                    scope const _text = toStringz(assumeWontThrow(text));
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

                        assumeWontThrow({
                            stderr.writefln("\t%s:%s: Format expression did throw", task_name, level);
                            stderr.writefln("%s", e);
                        }());
                    }
                }
            }
        }
    }

    /// Conditional subscription logging
    @trusted
    void event(ref Topic topic, lazy string identifier, lazy const(Document) data) const nothrow {
        locateLoggerSubscriptionTask();
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

    void event(T)(ref Topic topic, lazy string identifier, lazy T data) const nothrow
            if (isHiBONRecord!T) {
        event(topic, identifier, data.toDoc);
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

    @trusted
    void fatal(const(Throwable) t) const nothrow {
        auto mt = cast(Throwable)t;
        fatal(mt.toString);
    }

    void fatal(lazy string text) const nothrow {
        report(LogLevel.FATAL, text);
    }

    void fatal(Args...)(string fmt, lazy Args args) const nothrow {
        report(LogLevel.FATAL, fmt, args);
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
final synchronized class SubscriptionMask {
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
        if (thisTid == logger_subscription_tid) {
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
        if (thisTid == logger_subscription_tid) {
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
shared static this() {
    submask = new SubscriptionMask();
}

unittest {
    import core.time;

    Topic topic = Topic("some_tag");
    assert(!topic.subscribed, "Topic was subscribed, it shouldn't");
    register("log_sub_task", thisTid);
    log.registerSubscriptionTask("log_sub_task");
    auto some_symbol = Document.init;
    log.event(topic, "", some_symbol);
    assert(false == receiveTimeout(Duration.zero, (LogInfo _, const(Document) __) {
        }), "Received an unsubscribed topic");
    submask.subscribe(topic.name);
    assert(topic.subscribed, "Topic wasn't subscribed, it should");
    log.event(topic, "", some_symbol);
    assert(true == receiveTimeout(Duration.zero, (LogInfo _, const(Document) __) {
        }), "Didn't receive subscribed topic");
}

version (Posix) {
    import core.sys.posix.pthread;

    /* 
     * Note: non portable
     * Although implemented on most platforms, it might behave differently
     */
    extern (C) int pthread_setname_np(pthread_t, const char*) nothrow;

    // The max task name length is set when you compile your kernel,
    // You might have set it differently
    enum TASK_COMM_LEN = 16;

    /**
     * Set the thread name to the same as the task name
     * Note. Makes it easier to debug because pthread name is the same as th task name
     * Cuts of the name if longer than length allowed by the kernel
    **/
    @trusted
    int setThreadName(string _name) nothrow {
        // dfmt off
        string name = (_name.length < TASK_COMM_LEN)
            ? _name ~ '\0'
            : _name[0 .. TASK_COMM_LEN - 1] ~ '\0';
        // dfmt on
        assert(name.length <= TASK_COMM_LEN);
        return pthread_setname_np(pthread_self(), &name[0]);
    }

    @safe
    unittest {
        assert(setThreadName("antonio") == 0, "Could not set short thread name");
        assert(setThreadName("antoniofernandesthe3rd") == 0, "Could not set long thread name");
    }
}
else {
    int setThreadName(string _) @safe nothrow {
        return 0;
    }
}
