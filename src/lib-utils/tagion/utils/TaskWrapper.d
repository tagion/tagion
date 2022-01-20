module tagion.utils.TaskWrapper;

import std.stdio;
import std.format;
import std.traits : isCallable;
import tagion.basic.Basic : Control;

struct TaskMethod {
}

struct Task(alias Func) {
    static assert(is(Func == struct));
    import std.traits : Parameters, ParameterIdentifierTuple, isFunction, isDelegate, isFunctionPointer, hasUDA, getUDAs;
    import std.meta : AliasSeq;
    import std.exception;
    import std.concurrency;

    alias Params=Parameters!Func;
    alias ParamNames=ParameterIdentifierTuple!Func;

    private Tid _tid;
    immutable(string) task_name;

    this(string task_name, Params args) {
        this.task_name=task_name;
        _tid = spawn(&run, task_name, args);
        version(none) {
        // Should we do the check and log if there is error but not stop the execution? 
        check(receiveOnly!Control is Control.LIVE);
        }
    }

    static if (is(Func == struct)) {
        static string generateSendFunctions() {
            import std.array : join;
            string[] result;
            static foreach(m; __traits(allMembers, Func)) {{
                    enum code=format!(q{alias Type=Func.%s;})(m);
                    mixin(code);
                    static if (isCallable!Type && hasUDA!(Type, TaskMethod)) {
                        enum method_code=format!q{
                            alias FuncParams_%1$s=AliasSeq!%2$s;
                            void %1$s(FuncParams_%1$s args) {
                                _tid.send(args);
                                    }}(m, Parameters!(Type).stringof);
                        result~=method_code;
                    }
                         }}
            return result.join("\n");
        }
        enum send_methods=generateSendFunctions;
        mixin(send_methods);
    }
    
    version(none)
    void stop() const {
        _tid.send(Control.STOP);
        receive((Control control) =>
                check(control is Control.END, "Bad something")
            );
    }

    static void run(string task_name, Params args) nothrow {
        try {
            scope(success) {
                assumeWontThrow(writefln("Success"));
            }
            scope(failure) {
                assumeWontThrow(writefln("Fail"));
                // Send logs?
            }
            scope(exit) {
                ownerTid.prioritySend(Control.END);
            }
            
            version(none) {
                // TODO: fix logger for tasks
                log.register(task_name);
            }

            Func task;
            // Boiler coded
            task(args);
        }
        catch (Exception e) {
            assumeWontThrow(writefln("%s", e));
        }
    }
}

mixin template TaskBasic() {
    import concurrency=std.concurrency;
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
        with(Control) {
            final switch(control) {
            case STOP: onSTOP;
                break;
            case LIVE: onLIVE;
                break;
            case END: onEND;
                break;
            }
        }
    }
}

struct FakeTask {
    import std.concurrency;
    import std.string : StringException;
    mixin TaskBasic;

    @TaskMethod void echo_string(string test_string) {
        ownerTid.send(test_string);
    }

    @TaskMethod void throwing_method(int n) {
        throw new StringException("You shall not pass");
    }

    void opCall(int x, uint y) {
        ownerTid.send(Control.LIVE);
        while(!stop) {
            receive(
                &control,
                &echo_string,
                &throwing_method);
        }
    }
}

unittest {
    import std.concurrency : receiveOnly, receive;
    import std.variant : Variant;

    void CheckReceive(Variant check_control) {
        receive(
            (Control c) { assert(c == check_control); },
            (string s)  { assert(s == check_control); },
            (Variant v) { assert(false); },
        );
    }

    // Spawn fake task
    alias fake_task=Task!FakeTask;
    auto task=fake_task("fake_task_name", 10, 20);
    CheckReceive(Variant(Control.LIVE));

    // Check sending some string back and forth
    enum test_string = "send some text";
    task.echo_string(test_string);
    CheckReceive(Variant(test_string));

    // Check handling exceptions
    task.throwing_method(10); 
    CheckReceive(Variant(Control.END));

    // Check stopping task using Control.STOP
    auto task2=fake_task("another_fake_task_name", 10, 20);
    CheckReceive(Variant(Control.LIVE));
    task2.control(Control.STOP);
    CheckReceive(Variant(Control.END));
}
