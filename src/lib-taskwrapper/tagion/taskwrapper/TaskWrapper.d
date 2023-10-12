module tagion.taskwrapper.TaskWrapper;

import std.stdio;
import std.format;
import std.traits : isCallable;
import std.typecons : Tuple;
import std.range;
import std.algorithm.mutation : remove;

import tagion.basic.Types : Control;
import tagion.basic.basic : TrustedConcurrency;
import tagion.basic.traits : hasOneMemberUDA;
import tagion.logger.Logger;
import tagion.logger.LogRecords : LogFilter, LogFilterArray, LogFiltersAction, LogInfo;
import tagion.actor.exceptions : fatal, TaskFailure;
import tagion.prior_services.LoggerService;
import tagion.dart.Recorder;
import tagion.hibon.Document : Document;

alias Recorder = RecordFactory.Recorder;

mixin TrustedConcurrency;

enum TaskMethod;

alias TaskInfo = Tuple!(Tid, "tid", string, "task_name");
@safe struct TidTable {
    import std.container;

    private TaskInfo[] array;

    bool empty() const {
        return array.empty;
    }

    void push_back(TaskInfo elem) {
        array ~= elem;
    }

    TaskInfo pop_back() {
        if (array.empty)
            return TaskInfo();

        auto e = back;
        array = array.remove(array.length - 1);
        return e;
    }

    TaskInfo back() {
        if (array.empty)
            return TaskInfo();

        return array[$ - 1];
    }

    bool removeTask(string task_name) {
        foreach (i; 0 .. array.length) {
            if (array[i].task_name == task_name) {
                array = array.remove(i);
                return true;
            }
        }
        return false;
    }
}

unittest {
    log.silent = true;
    TidTable table;
    assert(table.empty);

    auto info0 = TaskInfo(thisTid, "info0");
    auto info1 = TaskInfo(Tid.init, "info1");
    auto info2 = TaskInfo(thisTid, "info2");

    table.push_back(info0);
    assert(!table.empty);
    assert(table.back == info0);

    table.push_back(info1);
    assert(!table.empty);
    assert(table.back == info1);

    table.push_back(info2);
    assert(!table.empty);
    assert(table.back == info2);

    const wrong_name = "wrong_name";
    assert(!table.removeTask(wrong_name));

    assert(table.removeTask(info1.task_name));
    assert(table.pop_back == info2);
    assert(table.pop_back == info0);
    assert(table.empty);
}

@safe struct Task(alias Func) {
    static assert(is(Func == struct));
    import std.traits : Parameters, ParameterIdentifierTuple, isFunction, isDelegate, isFunctionPointer, hasUDA;
    import std.meta : AliasSeq;
    import std.exception;
    import std.typecons : Typedef;

    alias Params = Parameters!Func;
    alias ParamNames = ParameterIdentifierTuple!Func;

    immutable(string) task_name;
    private Tid _tid;

    private static TidTable _tid_table;

    this(string task_name, Params args) {
        this.task_name = task_name;
        _tid = spawn(&run, task_name, args);

        // Add to static table of tasks
        _tid_table.push_back(TaskInfo(_tid, task_name));
    }

    static if (is(Func == struct)) {
        static string generateSendFunctions() {
            import std.array : join;

            string[] result;
            static foreach (m; __traits(allMembers, Func)) {
                {
                    enum code = format!(q{alias Type=Func.%s;})(m);
                    mixin(code);
                    alias Overloads = __traits(getOverloads, Func, m);
                    static if (isCallable!Type && hasUDA!(Overloads[0], TaskMethod)) {
                        enum method_code = format!q{
                            alias FuncParams_%1$s=AliasSeq!%2$s;
                            void %1$s(FuncParams_%1$s args) {
                                send(_tid, args);
                                    }}(m, Parameters!(Type).stringof);
                        result ~= method_code;
                    }
                }
            }
            return result.join("\n");
        }

        enum send_methods = generateSendFunctions;
        mixin(send_methods);
    }

    static void registerLogger(string task_name) {
        static if (is(Func == LoggerTask)) {
            register(task_name, thisTid);
            log.set_logger_task(task_name);
        }
        else {
            log.register(task_name);
        }
    }

    static void run(string task_name, Params args) nothrow {
        try {
            scope (success) {
                log.trace(format("Success: TaskWrapper<%s>", task_name));
            }
            scope (failure) {
                log.warning(format("Fail: TaskWrapper<%s>", task_name));
            }
            scope (exit) {
                _tid_table.removeTask(task_name);
                prioritySend(ownerTid, Control.END);
            }

            registerLogger(task_name);

            Func task;
            // Boiler coded
            task(args);
        }
        catch (Exception e) {
            fatal(e);
        }
    }
}

@safe mixin template TaskBasic() {
    import std.typecons : Typedef;

    bool stop;
    // TODO Do we need handle also "abort"?

    // Task can redefine this method to customize actions when receiving Control.STOP
    void onSTOP() {
        stop = true;
    }

    // Task can redefine this method to customize actions when receiving Control.LIVE
    void onLIVE() {
        /// Should throw something
    }

    // Task can redefine this method to customize actions when receiving Control.END
    void onEND() {
        // If the task can spawn another tasks then it could receive LIVE and END
    }

    @TaskMethod void control(immutable(Control) control) {
        with (Control) {
            final switch (control) {
            case STOP:
                onSTOP;
                break;
            case LIVE:
                onLIVE;
                break;
            case END:
                onEND;
                break;
            }
        }
    }
}

version (unittest) @safe struct FakeTask {
    import std.string : StringException;

    mixin TaskBasic;

    @TaskMethod void echo_string(string test_string) {
        send(ownerTid, test_string);
    }

    @TaskMethod void throwing_method(int n) {
        throw new StringException("You shall not pass");
    }

    void opCall(int x, uint y) {
        send(ownerTid, Control.LIVE);
        while (!stop) {
            receive(
                    &control,
                    &echo_string,
                    &throwing_method);
        }
    }
}

version (none) @safe unittest {
    log.silent = true;
    import tagion.prior_services.Options : Options, setDefaultOption;
    import tagion.prior_services.LoggerService;
    import tagion.logger.Logger;

    enum main_task = "taskwrapperunittest";

    Options options;
    setDefaultOption(options);

    auto loggerService = Task!LoggerTask(options.logger.task_name, options);
    scope (exit) {
        loggerService.control(Control.STOP);
        assert(receiveOnly!Control is Control.END);
    }

    assert(receiveOnly!Control is Control.LIVE);

    log.register(main_task);

    // Spawn fake task
    enum fake_task_name = "fake_task_name";
    alias fake_task = Task!FakeTask;
    auto task = fake_task(fake_task_name, 10, 20);
    assert(receiveOnly!Control == Control.LIVE);

    // Check sending some string back and forth
    enum test_string = "send some text";
    task.echo_string(test_string);
    assert(receiveOnly!string == test_string);

    // Check handling exceptions
    task.throwing_method(10);
    assert(receiveOnly!Control == Control.END);
    pragma(msg, "fixme(ib): check for 'locate(task_name)' after adding application tests");

    // Check stopping task using Control.STOP
    enum another_fake_task_name = "another_fake_task_name";
    auto task2 = fake_task(another_fake_task_name, 10, 20);
    assert(receiveOnly!Control == Control.LIVE);
    task2.control(Control.STOP);
    assert(receiveOnly!Control == Control.END);
    pragma(msg, "fixme(ib): check for 'locate(task_name)' after adding application tests");

    // TODO: add tests for tasks table

}
