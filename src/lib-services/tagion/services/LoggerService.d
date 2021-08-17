module tagion.services.LoggerService;

import std.stdio;
import std.format;
import std.concurrency;
import core.thread;
import core.sys.posix.pthread;
import std.string;

//extern(C) int pthread_setname_np(pthread_t, const char*);

import tagion.basic.Basic : Control;
import tagion.basic.Logger;

import tagion.Options : Options, setOptions, options;
import tagion.basic.TagionExceptions;
import tagion.GlobalSignals : abort;

void loggerTask(immutable(Options) opts) {
    setOptions(opts);

    scope (success) {
        ownerTid.prioritySend(Control.END);
        if (abort) {
            log.silent = true;
        }
    }

    @trusted void task_register() {
        writeln("REGISTER ", opts.logger.task_name);
        assert(register(opts.logger.task_name, thisTid));
    }

    task_register;
    log.set_logger_task(opts.logger.task_name);

    File file;
    const logging = opts.logger.file_name.length != 0;
    if (logging) {
        file.open(opts.logger.file_name, "w");
        file.writefln("Logger task: %s", opts.logger.task_name);
        file.flush;
    }
    scope (exit) {
        if (logging) {
            file.close;
            ownerTid.send(Control.END);
        }
    }

    scope (success) {
        if (logging) {
            file.writeln("Logger closed");
        }
    }

    bool stop;

    void controller(Control ctrl) @safe {
        with (Control) switch (ctrl) {
        case STOP:
            stop = true;
            file.writefln("%s Stopped ", opts.logger.task_name);
            break;
        default:
            file.writefln("%s: Unsupported control %s", opts.logger.task_name, ctrl);
        }
    }

    @trusted void receiver(LoggerType type, string label, string text) {
        void printToConsole(string s) {
            if (opts.logger.to_console) {
                writeln(s);
                if (opts.logger.flush) {
                    stdout.flush();
                }
            }
        }

        if (type is LoggerType.INFO) {
            const output = format("%s: %s", label, text);
            if (logging) {
                file.writeln(output);
            }
            printToConsole(output);
        }
        else {
            const output = format("%s:%s: %s", label, type, text);
            if (logging) {
                file.writeln(output);
            }
            printToConsole(output);
        }
        if (type & LoggerType.STDERR) {
            stderr.writefln("%s:%s: %s", label, type, text);
        }
    }

    ownerTid.send(Control.LIVE);
    while (!stop && !abort) {
        try {
            receive(&controller, &receiver);
            if (opts.logger.flush && logging) {
                file.flush();
            }
        }
        catch (TagionException e) {
            log.fatal(e.msg);
            stop = true;
            ownerTid.send(e.taskException);
        }
        catch (Exception e) {
            stderr.writefln("Logger error %s", e.msg);
            ownerTid.send(cast(immutable) e);
            stop = true;
        }
        catch (Throwable t) {
            t.msg ~= format(" - From logger task %s ", opts.logger.task_name);
            stderr.writeln(t.msg);
            ownerTid.send(cast(immutable) t);
            stop = true;
        }
    }

}
