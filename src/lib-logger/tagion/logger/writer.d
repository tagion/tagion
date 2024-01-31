module tagion.logger.writer;

@safe:

import std.stdio;
import std.conv;
import std.format;
import std.datetime;
import std.exception;

import tagion.logger.LogRecords;
import tagion.logger.Logger : LogLevel;
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

struct LogWriter {
    File fout;
    bool is_logger_service;
    string log_file;

    this(string log_file, bool is_logger_service = false) {
        this.is_logger_service = is_logger_service;
        this.log_file = log_file;
        if (is_logger_service) {
            fout = File(log_file, "w");
        }
    }

    static string formatLog(LogLevel level, string task_name, const(char[]) text, LogType log_type = LogType.Console) nothrow {
        const _format(string color = string.init) nothrow {
            const _RESET = (color is string.init) ? "" : RESET;
            final switch (log_type) {
            case LogType.Console:
                return assumeWontThrow(format!LOG_FORMAT(Clock.currTime().toTimeSpec.tv_sec, color, level, _RESET, task_name, text));
            case LogType.File:
                return assumeWontThrow(format!LOG_FORMAT(Clock.currTime().toTimeSpec.tv_sec, "", level, "", task_name, text));
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

    static void stdoutwrite(const LogInfo info, const(char[]) text) nothrow @trusted {
        try {
            stdout.writeln(formatLog(info.level, info.task_name, text));
        }
        catch (Exception e) {
            debug assert(0, e.message);
        }
    }

    void write(const LogInfo info, const(char[]) text) nothrow {
        assert(is_logger_service, "Only the logger service should call this");
        assert(info.isTextLog, "You should only pass text logs here");
        try {
            fout.writeln(formatLog(info.level, info.task_name, text));
        }
        catch (StdioException e) {
        }
        catch (Exception e) {
            /// Uh?
            debug assert(0, e.message);
        }
    }
}
