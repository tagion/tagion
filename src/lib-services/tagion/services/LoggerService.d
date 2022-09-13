/// \file LoggerService.d

/// \page LoggerService

/** @brief Service for logging everythinh
 */

module tagion.services.LoggerService;

import std.array;
import std.stdio;
import std.format;
import core.thread;
import core.sys.posix.pthread;
import std.string;
import std.algorithm : any;

//extern(C) int pthread_setname_np(pthread_t, const char*);

import tagion.basic.Types : Control;
import tagion.basic.TagionExceptions;
import tagion.GlobalSignals : abort;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.services.LogSubscriptionService : logSubscriptionServiceTask;
import tagion.services.Options : Options, setOptions, options;
import tagion.logger.Logger;
import tagion.logger.LogRecords;

import tagion.basic.Basic : TrustedConcurrency;

mixin TrustedConcurrency;

import tagion.tasks.TaskWrapper;

/**
 * Main function of LoggerService
 * @param optiions
 */
@safe struct LoggerTask
{
    mixin TaskBasic;

    LogFilter[] commonLogFilters;
    pragma(msg, "fixme(ib) Spawn LogSubscriptionService from LoggerService");
    Tid logSubscriptionTid;

    Options options;

    File file;
    bool logging;

    void sendToLogSubService(Args...)(Args args)
    {
        if (logSubscriptionTid is Tid.init)
        {
            logSubscriptionTid = locate(options.logSubscription.task_name);
        }

        if (logSubscriptionTid !is Tid.init)
        {
            logSubscriptionTid.send(args);
        }
    }

    bool matchAnyFilter(LogFilter filter)
    {
        return commonLogFilters.any!(f => (f.match(filter)));
    }

    @TaskMethod void receiveLogs(immutable(LogFilter) filter, immutable(Document) data) @trusted // was safe by default
    {
        if (matchAnyFilter(filter))
        {
            sendToLogSubService(filter, data);
        }

        if (filter.isTextLog)
        {
            if (data.hasMember(TextLog.label))
            {
                const log_msg = data[TextLog.label].get!string;

                string output;
                if (filter.level is LogLevel.INFO)
                {
                    output = format("%s: %s", filter.task_name, log_msg);
                }
                else
                {
                    output = format("%s:%s: %s", filter.task_name, filter.level, log_msg);
                }

                if (logging)
                {
                    file.writeln(output);
                }

                void printToConsole(string s) @trusted
                {
                    if (options.logger.to_console)
                    {
                        writeln(s);
                        if (options.logger.flush)
                        {
                            stdout.flush();
                        }
                    }
                }

                printToConsole(output);

                void printStdError(LogLevel level, string task_name, string log_msg) @trusted
                {
                    if (level & LogLevel.STDERR)
                    {
                        stderr.writefln("%s:%s: %s", task_name, level, log_msg);
                    }
                }

                printStdError(filter.level, filter.task_name, log_msg);

            }
        }
    }

    @TaskMethod void receiveFilters(LogFilterArray filters)
    {
        pragma(msg, "fixme(cbr): This accumulate alot for trach memory on the heap");

        commonLogFilters = filters.array.dup;
    }

    void onSTOP()
    {
        stop = true;
        file.writefln("%s stopped ", options.logger.task_name);

        if (abort)
        {
            log.silent = true;
        }
    }

    void onLIVE()
    {
        writeln("LogSubscriptionService is working...");
    }

    void onEND()
    {
        writeln("LogSubscriptionService was stopped");
    }

    void opCall(immutable(Options) options)
    {
        this.options = options;
        setOptions(options);

        pragma(msg, "fixme(ib) Pass mask to Logger to not pass not necessary data");

        if (options.logSubscription.enable)
        {
            logSubscriptionTid = spawn(&logSubscriptionServiceTask, options);
        }
        scope (exit)
        {
            import std.stdio;

            if (logSubscriptionTid !is Tid.init)
            {
                logSubscriptionTid.send(Control.STOP);
                if (receiveOnly!Control == Control.END) // TODO: can't receive END when stopping after logservicetest, fix it
                {
                    writeln("Canceled task LogSubscriptionService");
                    writeln("Received END from LogSubscriptionService");
                }
            }
        }

        logging = options.logger.file_name.length != 0;
        if (logging)
        {
            file.open(options.logger.file_name, "w");
            file.writefln("Logger task: %s", options.logger.task_name);
            file.flush;
        }

        ownerTid.send(Control.LIVE);
        while (!stop && !abort)
        {
            receive(&control, &receiveLogs, &receiveFilters);
            if (options.logger.flush && logging)
            {
                file.flush();
            }
        }
    }
}
