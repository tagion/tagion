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

import tagion.services.Options : Options, setOptions, options;
import tagion.basic.TagionExceptions;
import tagion.GlobalSignals : abort;

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
        bool matchAnyFilter(string task_name, LoggerType log_level) const nothrow {
            foreach (filter; log_filters) {
                if (filter.match(task_name, log_level)) {
                    return true;
                }
            }
            return false;
        }

        void sendToLogSubscriptionService(string task_name, LoggerType log_level, string log_output) {
            writeln("sendToLogSubscriptionService; ", task_name, ": ", log_level);
            // TODO
            // send()
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
        // scope (exit) {
        //     if (logging) {
        //         file.close;
        //         ownerTid.send(Control.END);
        //     }
        // }

        // scope (success) {
        //     if (logging) {
        //         file.writeln("Logger closed");
        //     }
        // }

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

        void filterReceiver(LogFilterArray array) {
            pragma(msg, "fixme(cbr): This accumulate alot for trach memory on the heap");
            log_filters = array.filters.dup;
//            writeln(format("filterReceiver; length = %d", log_filters.length));
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
