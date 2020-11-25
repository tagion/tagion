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

void loggerTask(immutable(Options) opts) {
    setOptions(opts);

    scope(success) {
        ownerTid.prioritySend(Control.END);
    }

    @trusted
    void task_register() {
        writeln("REGISTER ", opts.logger.task_name);
        assert(register(opts.logger.task_name, thisTid));
    }
    task_register;
    log.set_logger_task(opts.logger.task_name);

    File file;
    file.open(opts.logger.file_name, "w");
    file.writefln("Logger task: %s", opts.logger.task_name);
    file.flush;
    File error_file;
    error_file.open(["error", opts.logger.file_name].join("_"), "w");
    error_file.writefln("Logger task: %s", opts.logger.task_name);
    error_file.flush;
    scope(exit) {
        file.close;
        error_file.close;
        ownerTid.send(Control.END);
    }

    scope(success) {
        file.writeln("Logger closed");
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
        void printToConsole(string s)
        {
            if(opts.logger.to_console) writeln(s);
        }
        if ( type is LoggerType.INFO ) {
            const output = format("%s: %s", label, text);
            file.writeln(output);
            printToConsole(output);
        }
        else {
            const output = format("%s:%s: %s", label, type, text);
            file.writeln(output);
            printToConsole(output);
        }
        if ( type & LoggerType.STDERR) {
            const output = format("%s:%s: %s", label, type, text);
            stderr.writefln(output);
            error_file.writefln(output);
            error_file.flush;
        }
    }

    ownerTid.send(Control.LIVE);
    while(!stop) {
        try {
            receive(
                &controller,
                &receiver
            );
            if(opts.logger.flush){
                file.flush();
            }
        }
        catch(TagionException e){
            log.fatal(e.msg);
            stop=true;
            ownerTid.send(e.taskException);
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
