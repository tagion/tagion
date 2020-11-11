module tagion.basic.Logger;

//import core.thread;
import std.concurrency;
import core.sys.posix.pthread;
import std.string;
import std.stdio : stderr;
import tagion.basic.Basic : Control;

extern(C) int pthread_setname_np(pthread_t, const char*);

enum LoggerType {
    INFO    = 1,
    TRACE   = INFO<<1,
    WARNING = TRACE<<1,
    ERROR   = WARNING <<1,
    FATAL   = ERROR<<1,
    ALL     = INFO|TRACE|WARNING|ERROR|FATAL,
    STDERR  = WARNING|ERROR|FATAL
}


@safe
static struct Logger {
    protected {
        string _task_name;
        Tid logger_tid;
        uint id;
        uint[] masks;
        bool no_task;
    }

    @trusted
    static setThreadName(string name) {
        pthread_setname_np(pthread_self(), toStringz(name));
    }

    @trusted
    void register(string task_name)
        in {
            assert(logger_tid == logger_tid.init);
        }
    do {
        push(LoggerType.ALL);
        .register(task_name, thisTid);
        //logger_tid=locate(options.logger.task_name);
        _task_name=task_name;
        setThreadName(task_name);
        stderr.writefln("Register: %s logger", _task_name);
        log("Register: %s logger", _task_name);
    }

    @property @trusted
    void task_name(string task_name)
        in {
            assert(logger_tid == logger_tid.init);
        }
    do {
        no_task=true;
//        logger_tid=locate(options.logger.task_name);
        _task_name=task_name;
        setThreadName(task_name);
        log("Register: %s logger", _task_name);
    }

    @trusted
    void set_logger_task(string logger_task_name)
        in {
            assert(logger_tid != logger_tid.init);
        }
    do {
        logger_tid=locate(logger_task_name);
    }

    @property @nogc
    string task_name() pure const nothrow {
        return _task_name;
    }

    void push(const uint mask) {
        masks~=mask;
    }

    uint pop() {
        uint result=masks[$-1];
        if ( masks.length > 1 ) {
            masks=masks[0..$-1];
        }
        return result;
    }

    @trusted
    void report(LoggerType type, lazy string text) {
        if ( type | masks[$-1] ) {
            if ((logger_tid == logger_tid.init) && (!no_task)) {
                stderr.writefln("ERROR: Logger not register for '%s'", _task_name);
                stderr.writefln("\t%s:%s: %s", _task_name, type, text);
            }
            else {
                logger_tid.send(type, _task_name, text);
            }
        }
    }

    void opCall(lazy string text) {
        report(LoggerType.INFO, text);
    }

    @trusted
    void opCall(Args...)(string fmt, lazy Args args) {
        opCall(format(fmt, args));
    }

    void trace(lazy string text) {
        report(LoggerType.TRACE, text);
    }

    void trace(Args...)(string fmt, lazy Args args) {
        trace(format(fmt, args));
    }


    void warning(lazy string text) {
        report(LoggerType.WARNING, text);
    }

    void warning(Args...)(string fmt, Args args) {
        warning(format(fmt, args));
    }

    void error(Args...)(string fmt, lazy Args args) {
        error(format(fmt, args));
    }

    void error(lazy string text) {
        report(LoggerType.ERROR, text);
    }

    void fatal(Args...)(string fmt, lazy Args args) {
        fatal(format(fmt, args));
    }

    void fatal(lazy string text) {
        report(LoggerType.FATAL, text);
    }

    @trusted
    void close() {
        logger_tid.send(Control.STOP);
    }
}


static Logger log;
