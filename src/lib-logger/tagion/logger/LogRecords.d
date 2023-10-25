/// \file LogRecords.d

module tagion.logger.LogRecords;

import tagion.hibon.HiBONRecord;
import tagion.logger.Logger : LogLevel, Topic;

/** @brief Definitions of auxiliary structs and types for working with logs
 */

/**
 * \enum LogFiltersAction
 * Defines type of action for list of log filters
 */
enum LogFiltersAction {
    ADD,
    REMOVE
}

/**
 * \struct LogFilter
 * Struct represents filter for receiving logs
 */
@safe struct LogFilter {
    /** Task name to listen */
    @label("task") string task_name;
    /** Log level. Applied for text logs */
    @label("level") LogLevel level;
    /** Name of symbol to listen. Optional field */
    @label("symbol") string symbol_name;

    mixin HiBONRecord!(q{
        /** Ctor for text logs
          *     @param task_name - task name
          *     @param level - log level
          */
        this(string task_name, LogLevel level) nothrow {
            this.task_name = task_name;
            this.level = level;
            this.symbol_name = "";
        }

        /** Ctor for symbol logs
          *     @param task_name - task name
          *     @param symbol_name - symbol name
          */
        this(string task_name, string symbol_name) nothrow {
            this.task_name = task_name;
            this.level = LogLevel.ALL;
            this.symbol_name = symbol_name;
        }

        /** Ctor from \link LogInfo
          *     @param info - log info for creating filter
          */
        this(in LogInfo info) nothrow
        {
            if (info.isTextLog)
            {
                this(info.task_name, info.level);
            }
            else
            {
                this(info.task_name, info.symbol_name);
            }
        }
    });

    /** Method that check if given filter matches current filter
      *     @param filter - given filter to check for matching
      *     @return result of check
      */
    @nogc bool match(in LogFilter filter) pure const nothrow {
        return this.task_name == filter.task_name && this.level & filter.level && this.symbol_name == filter
            .symbol_name;
    }

    /** Method that check if given log info matches current filter
      *     @param info - given log info to check for matching
      *     @return result of check
      */
    @nogc bool match(in LogInfo info) pure const nothrow {
        if (this.isTextLog != info.isTextLog) {
            return false;
        }

        bool result;
        if (info.isTextLog) {
            result = this.task_name == info.task_name && this.level & info.level;
        }
        else {
            result = this.task_name == info.task_name && this.symbol_name == info.symbol_name;
        }
        return result;
    }

    /** Method that check if current filter for text log
      *     @return result of check
      */
    @nogc bool isTextLog() pure const nothrow {
        import std.range;

        return symbol_name.empty;
    }
}

/**
 * \struct LogFilterArray
 * Struct stores array of \link LogFilter
 */
@safe struct LogFilterArray {
    /** Array of filters */
    immutable(LogFilter[]) array;

    /** Main ctor
      *     @param filters - array of filters
      */
    this(immutable(LogFilter[]) filters) nothrow {
        this.array = filters;
    }
}

/**
 * \struct TextLog
 * Struct for wrapping text log into \link HiBONRecord
 */
@safe struct TextLog {
    /** Text log message */
    @label("msg") string message;

    mixin HiBONRecord!(q{
        /** Main ctor
         *     @param msg - text message
         */
        this(string msg) nothrow {
            this.message = msg;
        }
    });
}

/**
 * \struct LogInfo
 * Struct stores info about passing log
 */
@safe struct LogInfo {
    private {
        /** Value that stores type of log */
        const bool _is_text_log;
    }

    /** Task name */
    const string task_name;
    /** Log level */
    const LogLevel level;

    /** Ctor for text logs
     *     @param task_name - task name
     *     @param level - log level
     */
    this(string task_name, LogLevel level) nothrow pure {
        this.task_name = task_name;
        this.level = level;

        _is_text_log = true;
    }

    const string topic_name;
    /** Symbol name */
    const string symbol_name;

    /** Ctor for symbol logs
     *     @param task_name - task name
     *     @param symbol_name - symbol name
     */
    this(Topic topic, string task_name, string symbol_name) nothrow pure {
        this.task_name = task_name;
        this.topic_name = topic.name;
        this.symbol_name = symbol_name;

        _is_text_log = false;
    }

    /** Method that return whether current filter is text log
      *     @return result
      */
    @nogc bool isTextLog() pure const nothrow {
        return _is_text_log;
    }
}

unittest {
    enum task1 = "sometaskname";
    enum task2 = "anothertaskname";
    enum symbol1 = "some_symbol";
    enum symbol2 = "another_symbol";

    /// LogFilter_match_symmetrical
    {
        auto f1 = LogFilter(task1, LogLevel.STDERR);
        auto f2 = LogFilter(task1, LogLevel.ERROR);

        assert(f1.match(f2));
        assert(f2.match(f1));
    }

    /// LogFilter_match_text_logs
    {
        assert(LogFilter(task1, LogLevel.ERROR).match(LogFilter(task1, LogLevel.STDERR)));
        assert(LogFilter(task1, LogLevel.ALL).match(LogFilter(task1, LogLevel.INFO)));
        assert(LogFilter(task2, LogLevel.ERROR).match(LogFilter(task2, LogLevel.ERROR)));

        assert(!LogFilter(task1, LogLevel.STDERR).match(LogFilter(task1, LogLevel.INFO)));
        assert(!LogFilter(task1, LogLevel.ERROR).match(LogFilter(task2, LogLevel.ERROR)));
        assert(!LogFilter(task1, LogLevel.INFO).match(LogFilter("", LogLevel.INFO)));

        assert(!LogFilter(task1, LogLevel.NONE).match(LogFilter(task1, LogLevel.NONE)));
    }

    /// LogFilter_match_text_log_info
    {
        assert(LogFilter(task1, LogLevel.STDERR).match(LogInfo(task1, LogLevel.ERROR)));
        assert(LogFilter(task1, LogLevel.ALL).match(LogInfo(task1, LogLevel.INFO)));

        assert(!LogFilter(task1, LogLevel.STDERR).match(LogInfo(task1, LogLevel.INFO)));
        assert(!LogFilter(task1, LogLevel.INFO).match(LogInfo(task2, LogLevel.INFO)));

        assert(!LogFilter(task1, LogLevel.NONE).match(LogInfo(task1, LogLevel.NONE)));
    }

    /// LogFilter_match_symbol_log
    {
        assert(LogFilter(task1, symbol1).match(LogFilter(task1, symbol1)));
        assert(LogFilter(task2, symbol2).match(LogFilter(task2, symbol2)));

        assert(!LogFilter(task1, symbol1).match(LogFilter(task1, LogLevel.ALL)));
        assert(!LogFilter(task1, symbol1).match(LogFilter(task1, symbol2)));
        assert(!LogFilter(task1, symbol1).match(LogFilter(task1, "")));
    }

    /// LogFilter_match_symbol_log_info
    {
        assert(LogFilter(task1, symbol1).match(LogInfo(Topic(""), task1, symbol1)));

        assert(!LogFilter(task1, symbol1).match(LogInfo(Topic(""), task1, symbol2)));
        assert(!LogFilter(task1, symbol1).match(LogInfo(task1, LogLevel.ALL)));
    }

    /// LogFilter_isTextLog
    {
        assert(LogFilter(task1, LogLevel.ERROR).isTextLog);
        assert(LogFilter(task1, LogLevel.NONE).isTextLog);
        assert(LogFilter(task1, "").isTextLog);

        assert(!LogFilter(task1, symbol1).isTextLog);
    }

    /// LogInfo_isTextLog
    {
        assert(LogInfo(task1, LogLevel.ERROR).isTextLog);
        assert(LogInfo(task1, LogLevel.NONE).isTextLog);

        assert(!LogInfo(Topic(), task1, symbol1).isTextLog);
        assert(!LogInfo(Topic(), task1, "").isTextLog);
    }
}
