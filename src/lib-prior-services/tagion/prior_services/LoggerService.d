/// Service for handling both text logs and variable logging
module tagion.prior_services.LoggerService;

import std.array;
import std.stdio;
import std.format;
import core.thread;
import core.sys.posix.pthread;
import std.string;
import std.algorithm : any, filter;
import std.algorithm.searching : canFind;
import std.datetime.systime : Clock;
import std.conv : to;

import tagion.basic.basic : TrustedConcurrency, assumeTrusted;
import tagion.basic.Types : Control;
import tagion.basic.tagionexceptions;
import tagion.GlobalSignals : abort;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;

//import tagion.prior_services.LogSubscriptionService : logSubscriptionServiceTask;
import tagion.prior_services.Options : Options, setOptions, options;
import tagion.logger.Logger;
import tagion.logger.LogRecords;
import tagion.taskwrapper.TaskWrapper;
import tagion.dart.BlockFile : truncate;

mixin TrustedConcurrency;

private {
    enum TIMESTAMP_WIDTH = 10;
    enum LOG_LEVEL_MAX_WIDTH = 5;

    enum LOG_FORMAT = "%-" ~ to!string(
                TIMESTAMP_WIDTH) ~ "s | %-" ~ to!string(
                LOG_LEVEL_MAX_WIDTH) ~ "s | %s: %s";
}

/**
 * LoggerTask
 * Struct represents LoggerService which handles logs and provides passing them to LogSubscriptionService
 */
@safe struct LoggerTask {
    mixin TaskBasic;

    /** Storage of current log filters, received from LogSubscriptionService */
    LogFilter[] commonLogFilters;
    /** LogSubscriptionService thread id */
    Tid logSubscriptionTid;

    /** Service options */
    Options options;

    /** File for writing text logs */
    File file;
    /** Flag that enables logging output to file */
    bool logging;

    /** Method that helps sending arguments to LogSubscriptionService 
     *      @param args - arbitrary list of arguments to send to service
     */
    void sendToLogSubService(Args...)(Args args) {
        if (logSubscriptionTid is Tid.init) {
            logSubscriptionTid = locate(options.logsubscription.task_name);
        }

        if (logSubscriptionTid !is Tid.init) {
            logSubscriptionTid.send(args);
        }
    }

    /** Method that checks whether given log info matches at least one stored filter 
     *      @param info - log info to check
     *      \return boolean result of checking
     */
    bool matchAnyFilter(LogInfo info) {
        return commonLogFilters.any!(f => (f.match(info)));
    }

    static string formatLog(LogLevel level, string task_name, string text) {
        return format(LOG_FORMAT, Clock.currTime().toTimeSpec.tv_sec, level, task_name, text);
    }

    /** Task method that receives logs from Logger and sends them to console, file and LogSubscriptionService
     *      @param info - log info about passed log
     *      @param doc - log itself, that can be either TextLog or some HiBONRecord variable
     */
    @TaskMethod void receiveLogs(immutable(LogInfo) info, immutable(Document) doc) {
        if (matchAnyFilter(info)) {
            sendToLogSubService(info, doc);
        }

        enum _msg = GetLabel!(TextLog.message).name;
        if (info.isTextLog && doc.hasMember(_msg)) {
            string output = formatLog(info.level, info.task_name, doc[_msg].get!string);

            // Output text log to file
            if (logging) {
                file.writeln(output);
                if (options.logger.trunc_size) {
                    const file_tell = file.tell;
                    if (options.logger.trunc_size <= file_tell) {
                        file.writefln("Truncated at %d", file_tell);
                        file.flush;
                        truncate(file, file_tell);
                        file.seek(0);
                    }
                }
            }

            // Output text log to console
            if (options.logger.to_console) {
                writeln(output);
                if (options.logger.flush) {
                    assumeTrusted!stdout.flush();
                }
            }

            // Output error log
            if (info.level & LogLevel.STDERR) {
                assumeTrusted!stderr.writefln(output);
            }
        }
    }

    /** Task method that receives filter updates from LogSubscriptionService
     *      @param filters - array of filter updates
     */
    @TaskMethod void receiveFilters(LogFilterArray filters, LogFiltersAction action) {
        if (action == LogFiltersAction.ADD) {
            commonLogFilters ~= filters.array;
        }
        else {
            commonLogFilters = commonLogFilters.filter!(f => filters.array.canFind(f)).array;
        }
    }

    /** Method that triggered when service receives Control.STOP.
     *  Receiving this signal means that LoggerService should be stopped
     */
    void onSTOP() {
        stop = true;
        file.writefln("%s stopped ", options.logger.task_name);

        if (abort) {
            log.silent = true;
        }
    }

    /** Method that triggered when service receives Control.LIVE.
     *  Receiving this signal means that LogSubscriptionService successfully running
     */
    void onLIVE() {
        writeln("LogSubscriptionService is working...");
    }

    /** Method that triggered when service receives Control.STOP.
     *  Receiving this signal means that LogSubsacriptionService successfully stopped
     */
    void onEND() {
        writeln("LogSubscriptionService was stopped");
    }

    /** Main method that starts service
     *      @param options - service options
     */
    void opCall(immutable(Options) options) {
        this.options = options;
        setOptions(options);

        pragma(msg, "fixme(ib) Pass mask to Logger to not pass not necessary data");

        version (none)
            if (options.logsubscription.enable) {
                logSubscriptionTid = spawn(&logSubscriptionServiceTask, options);
            }
        scope (exit) {
            import std.stdio;

            if (logSubscriptionTid !is Tid.init) {
                logSubscriptionTid.send(Control.STOP);
                if (receiveOnly!Control == Control.END) // TODO: can't receive END when stopping after logservicetest, fix it
                {
                    writeln("Canceled task LogSubscriptionService");
                    writeln("Received END from LogSubscriptionService");
                }
            }
        }

        logging = options.logger.file_name.length != 0;
        if (logging) {
            file.open(options.logger.file_name, "w");
            file.writefln("Logger task: %s", options.logger.task_name);
            file.flush;
        }

        ownerTid.send(Control.LIVE);
        while (!stop && !abort) {
            receive(&control, &receiveLogs, &receiveFilters);
            if (options.logger.flush && logging) {
                file.flush();
            }
        }
    }
}
