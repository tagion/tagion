module tagion.utils.TaskWrapper;

import std.stdio;
import std.format;
import std.traits : isCallable;
import tagion.basic.Basic : Control, TrustedConcurrency;
import tagion.logger.Logger;
import tagion.basic.TagionExceptions : fatal, TaskFailure;

mixin TrustedConcurrency;

@safe struct TaskMethod {
}

@safe struct Task(alias Func) {
    static assert(is(Func == struct));
    import std.traits : Parameters, ParameterIdentifierTuple, isFunction, isDelegate, isFunctionPointer, hasUDA, getUDAs;
    import std.meta : AliasSeq;
    import std.exception;

    alias Params = Parameters!Func;
    alias ParamNames = ParameterIdentifierTuple!Func;
    
    private Tid _tid;
    immutable(string) task_name;

    this(string task_name, Params args) {
        this.task_name = task_name;
        _tid = spawn(&run, task_name, args);
        // TODO add table
        version (none) {
            // Should we do the check and log if there is error but not stop the execution? 
            check(receiveOnly!Control is Control.LIVE);
        }
    }

    static if (is(Func == struct)) {
        static string generateSendFunctions() {
            import std.array : join;

            string[] result;
            static foreach (m; __traits(allMembers, Func)) {
                {
                    enum code = format!(q{alias Type=Func.%s;})(m);
                    mixin(code);
                    static if (isCallable!Type && hasUDA!(Type, TaskMethod)) {
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

    version (none) void stop() const {
        _tid.send(Control.STOP);
        receive((Control control) =>
                check(control is Control.END, "Bad something")
        );
    }

    static void run(string task_name, Params args) nothrow {
        try {
            scope (success) {
                assumeWontThrow(writefln("Success"));
            }
            scope (failure) {
                assumeWontThrow(writefln("Fail"));
                // Send logs?
            }
            scope (exit) {
                prioritySend(ownerTid, Control.END);
            }

            log.register(task_name);

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

version (unittest)
@safe struct FakeTask {
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

@safe unittest {
    import tagion.services.Options : Options, setDefaultOption;
    import tagion.services.LoggerService;
    import tagion.logger.Logger;
    
    enum main_task = "taskwrapperunittest";

    Options options;
    setDefaultOption(options);
    auto logger_tid = spawn(&loggerTask, options);
    scope (exit) {
        logger_tid.send(Control.STOP);
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
