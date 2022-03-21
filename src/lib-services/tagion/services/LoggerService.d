/// \file LoggerService.d


/// \page LoggerService

/** @brief Service for logging everythinh
 */

module tagion.services.LoggerService;

import std.stdio;
import std.format;
import std.concurrency;
import core.thread;
import core.sys.posix.pthread;
import std.string;

//extern(C) int pthread_setname_np(pthread_t, const char*);

import tagion.basic.Basic : Control;
import tagion.logger.Logger;
import tagion.services.LogSubscriptionService : logSubscriptionServiceTask;

import tagion.hibon.HiBONRecord;

import tagion.services.Options : Options, setOptions, options;
import tagion.basic.TagionExceptions;
import tagion.GlobalSignals : abort;

/** Struct with log filter
 */
@safe struct LogFilter {
    enum any_task_name = "";

    string task_name;
    LoggerType log_level;
    mixin HiBONRecord!(q{
        this(string task_name, LoggerType log_level) nothrow {
            this.task_name = task_name;
            this.log_level = log_level;
        }
    });

    @nogc bool match(string task_name, LoggerType log_level) pure const nothrow {
        return (this.task_name == any_task_name || this.task_name == task_name)
                && this.log_level & log_level;
    }
}

unittest {
    enum some_task_name = "sometaskname";
    enum another_task_name = "anothertaskname";

    assert(LogFilter("", LoggerType.ERROR).match(some_task_name, LoggerType.STDERR));
    assert(LogFilter(some_task_name, LoggerType.ALL).match(some_task_name, LoggerType.INFO));
    assert(LogFilter(some_task_name, LoggerType.ERROR).match(some_task_name, LoggerType.ERROR));

    assert(!LogFilter(some_task_name, LoggerType.STDERR).match(some_task_name, LoggerType.INFO));
    assert(!LogFilter(some_task_name, LoggerType.ERROR).match(another_task_name, LoggerType.ERROR));
}

/**
 * Main function of LoggerService
 * @param optiions
 */
void loggerTask(immutable(Options) opts) {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }

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

        LogFilter[] log_filters;
        @nogc bool matchAnyFilter(string task_name, LoggerType log_level) const nothrow pure {
            foreach (filter; log_filters) {
                if (filter.match(task_name, log_level)) {
                    return true;
                }
            }
            return false;
            // return log_filters.any({lambda...})
        }

        task_register;
        log.set_logger_task(opts.logger.task_name);

        pragma(msg, "fixme(ib) Spawn LogSubscriptionService from LoggerService");
        Tid log_subscription_tid;

        pragma(msg, "fixme(ib) Pass mask to Logger to not pass not necessary data");

        File file;
        const logging = opts.logger.file_name.length != 0;
        if (logging) {
            file.open(opts.logger.file_name, "w");
            file.writefln("Logger task: %s", opts.logger.task_name);
            file.flush;
        }

        void sendToLogSubscriptionService(string task_name, LoggerType log_level, string log_output) {
            if (log_subscription_tid is Tid.init) {
                log_subscription_tid = locate(opts.logSubscription.task_name);
            }

            if (log_subscription_tid !is Tid.init) {
                log_subscription_tid.send(task_name, log_level, log_output);
            }
        }

        bool stop;

        void controller(Control ctrl) @safe {
            with (Control) switch (ctrl) {
                case STOP:
                    stop = true;
                    file.writefln("%s Stopped ", opts.logger.task_name);
                    break;
                    // TODO: if spawn logger from here handle END    
                    //case END:
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

            string output;
            if (type is LoggerType.INFO) {
                output = format("%s: %s", label, text);
            }
            else {
                output = format("%s:%s: %s", label, type, text);
            }

            if (logging) {
                file.writeln(output);
            }
            printToConsole(output);
            if (matchAnyFilter(label, type)) {
                sendToLogSubscriptionService(label, type, output);
            }

            if (type & LoggerType.STDERR) {
                stderr.writefln("%s:%s: %s", label, type, text);
            }
        }

        void filterReceiver(LogFilter[] log_info) {
            log_filters = log_info;
        }

        ownerTid.send(Control.LIVE);
        while (!stop && !abort) {
            receive(&controller, &receiver, &filterReceiver);
            if (opts.logger.flush && logging) {
                file.flush();
            }
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
