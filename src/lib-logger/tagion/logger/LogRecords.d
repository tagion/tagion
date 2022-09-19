module tagion.logger.LogRecords;

import tagion.hibon.HiBONRecord;
import tagion.logger.Logger : LogLevel;

// TODO: doxygen

enum LogFiltersAction
{
    ADD,
    REMOVE
}

@safe struct LogFilter
{
    @Label("task") string task_name;
    @Label("level") LogLevel level;
    @Label("symbol") string symbol_name;

    mixin HiBONRecord!(q{
        this(string task_name, LogLevel level) nothrow {
            this.task_name = task_name;
            this.level = level;
            this.symbol_name = "";
        }

        this(string task_name, string symbol_name) nothrow {
            this.task_name = task_name;
            this.level = LogLevel.ALL;
            this.symbol_name = symbol_name;
        }
    });

    @nogc bool match(LogFilter filter) pure const nothrow
    {
        return this.task_name == filter.task_name && this.level & filter.level && this.symbol_name == filter
            .symbol_name;
    }

    @nogc bool isTextLog() pure const nothrow
    {
        import std.range;

        return symbol_name.empty;
    }
}

unittest
{
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

    /// LogFilter_match_symbol_log
    {
        assert(LogFilter(task1, symbol1).match(LogFilter(task1, symbol1)));
        assert(LogFilter(task2, symbol2).match(LogFilter(task2, symbol2)));

        assert(!LogFilter(task1, symbol1).match(LogFilter(task1, LogLevel.ALL)));
        assert(!LogFilter(task1, symbol1).match(LogFilter(task1, symbol2)));
        assert(!LogFilter(task1, symbol1).match(LogFilter(task1, "")));
    }

    /// LogFilter_isTextLog
    {
        assert(LogFilter(task1, LogLevel.ERROR).isTextLog);
        assert(LogFilter(task1, LogLevel.NONE).isTextLog);
        assert(LogFilter(task1, "").isTextLog);

        assert(!LogFilter(task1, symbol1).isTextLog);
    }
}

@safe struct LogFilterArray
{
    immutable(LogFilter[]) array;

    this(immutable(LogFilter[]) filters) nothrow
    {
        this.array = filters;
    }
}

@safe struct TextLog
{
    @Label("msg") string message;
    enum label = GetLabel!(message).name;

    mixin HiBONRecord!(q{
        this(string msg) nothrow {
            this.message = msg;
        }
    });
}
