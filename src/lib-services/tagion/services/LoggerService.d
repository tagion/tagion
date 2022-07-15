/// \file LoggerService.d

/// \page LoggerService

/** @brief Service for logging everythinh
 */

module tagion.services.LoggerService;

import std.stdio;
import std.format;
import core.thread;
import core.sys.posix.pthread;
import std.string;

//extern(C) int pthread_setname_np(pthread_t, const char*);

import tagion.basic.Types : Control;
import tagion.logger.Logger;
import tagion.services.LogSubscriptionService : logSubscriptionServiceTask;

import tagion.hibon.HiBONRecord;

import tagion.services.Options : Options, setOptions, options;
import tagion.basic.TagionExceptions;
import tagion.GlobalSignals : abort;

/** Struct with log filter
 */
@safe struct LogFilter
{
    enum any_task_name = "";

    string task_name;
    LoggerType log_level;
    mixin HiBONRecord!(q{
        this(string task_name, LoggerType log_level) nothrow {
            this.task_name = task_name;
            this.log_level = log_level;
        }
    });

    @nogc bool match(string task_name, LoggerType log_level) pure const nothrow
    {
        return (this.task_name == any_task_name || this.task_name == task_name)
            && this.log_level & log_level;
    }
}

unittest
{
    enum some_task_name = "sometaskname";
    enum another_task_name = "anothertaskname";

    assert(LogFilter("", LoggerType.ERROR).match(some_task_name, LoggerType.STDERR));
    assert(LogFilter(some_task_name, LoggerType.ALL).match(some_task_name, LoggerType.INFO));
    assert(LogFilter(some_task_name, LoggerType.ERROR).match(some_task_name, LoggerType.ERROR));

    assert(!LogFilter(some_task_name, LoggerType.STDERR).match(some_task_name, LoggerType.INFO));
    assert(!LogFilter(some_task_name, LoggerType.ERROR).match(another_task_name, LoggerType.ERROR));
}

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

    @nogc bool matchAnyFilter(string task_name, LoggerType type) const nothrow pure
    {
        foreach (filter; commonLogFilters)
        {
            if (filter.match(task_name, type))
            {
                return true;
            }
        }
        return false;
        // return commonLogFilters.any({lambda...})
    }

    @TaskMethod void receiveLogs(LoggerType type, string task_name, string log_msg)
    {
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

        void sendToLogSubscriptionService(LoggerType type, string task_name, string log_output)
        {
            if (logSubscriptionTid is Tid.init)
            {
                logSubscriptionTid = locate(options.logSubscription.task_name);
            }

            if (logSubscriptionTid !is Tid.init)
            {
                logSubscriptionTid.send(task_name, type, log_output);
            }
        }

        void printStdError(LoggerType type, string task_name, string log_msg) @trusted
        {
            if (type & LoggerType.STDERR)
            {
                stderr.writefln("%s:%s: %s", task_name, type, log_msg);
            }
        }

        string output;
        if (type is LoggerType.INFO)
        {
            output = format("%s: %s", task_name, log_msg);
        }
        else
        {
            output = format("%s:%s: %s", task_name, type, log_msg);
        }

        if (logging)
        {
            file.writeln(output);
        }
        printToConsole(output);
        if (matchAnyFilter(task_name, type))
        {
            sendToLogSubscriptionService(type, task_name, output);
        }

        printStdError(type, task_name, log_msg);
    }

    @TaskMethod void receiveFilters(immutable(LogFilter[]) filters)
    {
        pragma(msg, "fixme(cbr): This accumulate alot for trach memory on the heap");
        commonLogFilters = filters.dup;
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

        if (options.sub_logger.enable)
        {
            logSubscriptionTid = spawn(&logSubscriptionServiceTask, options);
        }
        scope (exit)
        {
            if (logSubscriptionTid !is Tid.init)
            {
                logSubscriptionTid.send(Control.STOP);
                receiveOnly!Control;
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
