/// Service for handling both text logs and variable logging
module tagion.services.logger;

@safe:

import std.array;
import std.conv : to;
import std.datetime.systime : Clock;
import std.format;
import std.stdio;
import std.string;
import tagion.actor;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.logger.LogRecords;
import tagion.logger.Logger;
import tagion.utils.Term;

private {
    enum TIMESTAMP_WIDTH = 10;
    enum LOG_LEVEL_MAX_WIDTH = 5;
    enum LOG_FORMAT = "%-" ~ TIMESTAMP_WIDTH.to!string ~ "s | %s%-" ~ LOG_LEVEL_MAX_WIDTH.to!string ~ "s%s | %s: %s";
}

enum LogType {
    Console, // Enables colored output
    File,
}

struct LoggerServiceOptions {
    LogType log_type = LogType.Console;
    string file; // Default is stdout
}

/**
 * LoggerTask
 * Struct represents LoggerService which handles logs and provides passing them to LogSubscriptionService
 */
struct LoggerService {

    immutable(LoggerServiceOptions) options;

    const(string) formatLog(LogLevel level, string task_name, string text) {
        const _format(string color = string.init) {
            const _RESET = (color is string.init) ? "" : RESET;
            final switch (options.log_type) {
            case LogType.Console:
                return format(LOG_FORMAT, Clock.currTime().toTimeSpec.tv_sec, color, level, _RESET, task_name, text);
            case LogType.File:
                return format(LOG_FORMAT, Clock.currTime().toTimeSpec.tv_sec, level, task_name, text);
            }
        }

        switch (level) with (LogLevel) {
        case TRACE:
            return _format(WHITE);
        case WARN:
            return _format(YELLOW);
        case ERROR:
            return _format(RED);
        case FATAL:
            return _format(BOLD ~ RED);
        default:
            return _format();
        }
    }

    void task() {
        File file;

        /** Task method that receives logs from Logger and sends them to console, file and LogSubscriptionService
         *      @param info - log info about passed log
         *      @param doc - log itself, that can be either TextLog or some HiBONRecord variable
         */
        void receiveLogs(immutable(LogInfo) info, immutable(Document) doc) {
            enum _msg = GetLabel!(TextLog.message).name;
            if (info.isTextLog && doc.hasMember(_msg)) {
                const output = formatLog(info.level, info.task_name, doc[_msg].get!string);
                if (!file.error) {
                    file.writeln(output);
                }
            }
        }

        if (options.file !is string.init) {
            file = File(options.file, "w");
        }
        else {
            file = (() @trusted => stdout())();
        }

        run(&receiveLogs);
    }
}
