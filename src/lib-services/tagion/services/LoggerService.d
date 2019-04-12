module tagion.services.LoggerService;

import std.stdio;
import std.format;
import std.concurrency;

import tagion.Base : Control;

import tagion.Options : Options, setOptions, options;

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
    protected string _task_name;
    protected Tid logger_tid;
    protected uint id;
    protected uint[] masks;
    // @trusted
    // this(string _task_name, string logger_task) {
    //     logger_tid=locate(logger_task);
    //     push(LoggerType.ALL);
    //     this._task_name=_task_name;
    // }

    @trusted
    void register(string task_name)
        in {
            assert(logger_tid == logger_tid.init);
        }
    do {
        push(LoggerType.ALL);
//        writefln("Before '%s'", locate(thisTid));
        .register(task_name, thisTid);
        logger_tid=locate(options.logger.task_name);
        _task_name=task_name;
        stderr.writefln("Register: %s logger=%s %s ", task_name, options.logger.task_name, (logger_tid != logger_tid.init));
    }

    @property
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
    void report(LoggerType type, string text) {
        if ( type | masks[$-1] ) {
            if (logger_tid == logger_tid.init) {
                stderr.writefln("ERROR: Logger not register for '%s'", _task_name);
                stderr.writefln("\t%s:%s: %s", _task_name, type, text);
            }
            else {
                logger_tid.send(type, _task_name, text);
            }
        }
    }

    void opCall(string text) {
        report(LoggerType.INFO, text);
    }

    @trusted
    void opCall(Args...)(string fmt, Args args) {
        opCall(format(fmt, args));
    }

    void trace(Args...)(string fmt, Args args) {
        report(LoggerType.TRACE, format(fmt, args));
    }

    void warning(Args...)(string fmt, Args args) {
        report(LoggerType.WARNING, format(fmt, args));
    }

    void warning(string text) {
        report(LoggerType.WARNING, text);
    }

    void error(Args...)(string fmt, Args args) {
        report(LoggerType.ERROR, format(fmt, args));
    }

    void error(string text) {
        report(LoggerType.ERROR, text);
    }

    void fatal(Args...)(string fmt, Args args) {
        report(LoggerType.FATAL, format(fmt, args));
    }

    void fatal(string text) {
        report(LoggerType.FATAL, text);
    }

    @trusted
    void close() {
        logger_tid.send(Control.STOP);
    }
}


static Logger log;

// static this() {
//     log=Logger(locate(thisTid), options.logger.task_name);
// }

void loggerTask(immutable(Options) opts) {
    setOptions(opts);
    @trusted
    void task_register() {
        assert(register(opts.logger.task_name, thisTid));
    }
    task_register;

    File file;
    file.open(opts.logger.file_name, "w");
    file.writefln("Logger task: %s", opts.logger.task_name);
    scope(exit) {
        file.writeln("Logger closed");
        file.close;
        ownerTid.send(Control.END);
    }

    bool stop;

    void controller(Control ctrl) @safe {
        with(Control) switch(ctrl) {
            case STOP:
                stop=true;
                file.writefln("%s Stopped ", opts.logger.task_name);
                break;
            default:
                file.writefln("%s: Unsupported control %s", opts.logger.task_name, ctrl);
            }
    }

    @trusted
    void receiver(LoggerType type, string label, string text) {
        if ( type is LoggerType.INFO ) {
            file.writefln("%s: %s", label, text);
        }
        else {
            file.writefln("%s:%s: %s", label, type, text);
        }
        if ( type & LoggerType.STDERR) {
            stderr.writefln("%s:%s: %s", type, label, text);
        }
    }

    ownerTid.send(Control.LIVE);
    while(!stop) {
        try {
            receive(
                &controller,
                &receiver
            );
        }
        catch ( Exception e ) {
            stderr.writefln("Logger error %s", e.msg);
            ownerTid.send(cast(immutable)e);
            stop=true;
        }
        catch ( Throwable t ) {
            t.msg ~= format(" - From logger task %s ", opts.logger.task_name);
            stderr.writeln(t.msg);
            ownerTid.send(cast(immutable)t);
            stop=true;

        }
    }
}
