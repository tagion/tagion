module tagion.utils.TaskWrapper;

import std.stdio;
import std.format;
import std.traits : isCallable;
import tagion.basic.Basic : Control;

struct TaskMethod {
}
void check(bool, string) {
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
    private static Tid[string] _tasks_table;
    immutable(string) task_name;
    this(string task_name, Params args) {
        writeln("CALLING ctor");
        this.task_name=task_name;
        _tid = spawn(&run, task_name, args);
        _tasks_table[task_name] = _tid;

        writeln("_tasks_table start -------------");
        writeln("size=", _tasks_table.length);
        foreach(k; _tasks_table.keys) {
            writeln(k, "->", _tasks_table[k]);
        }
        writeln("_tasks_table stop -------------");
        
        version(none) {
        check(receiveOnly!Control is Control.LIVE);
        }
    }
    version(none)
    Tid tid() pure nothrow {
        writeln("CALLING tid");
        return _tid;
    }
    // static void stopAllTasks() {
    //     foreach(task_tid, _tasks_table) {
    //         task_tid.send(Control.STOP);
    //     }
    // }
    static if (is(Func == struct)) {
        static string generateSendFunctions() {
            import std.array : join;
            string[] result;
            static foreach(m; __traits(allMembers, Func)) {{
                    pragma(msg, "member=", m);
                    enum code=format!(q{alias Type=Func.%s;})(m);
                    pragma(msg, code);
                    mixin(code);
                    static if (isCallable!Type && hasUDA!(Type, TaskMethod)) {
                        pragma(msg, "UDAs: ", getUDAs!(Type, TaskMethod));
                        pragma(msg, "Parameters: ", Parameters!Type);
                        enum method_code=format!q{
                            alias FuncParams_%1$s=AliasSeq!%2$s;
                            void %1$s(FuncParams_%1$s args) {
                                writeln("generated params sent: ", args);
                                _tid.send(args);
                                    }}(m, Parameters!(Type).stringof);
                        pragma(msg, "method_code: ", method_code);
                        result~=method_code;
                    }
                         }}
            return result.join("\n");
        }
        pragma(msg, ": ", __traits(allMembers, Func));
        enum send_methods=generateSendFunctions;
        mixin(send_methods);

        void control_dummy(immutable Control ctrl) {
            writeln("CALLING control_dummy");
            writeln("sending control_dummy... ", ctrl);
            _tid.send(ctrl);
        }
    }
    version(none)
    void stop() const {
        writeln("CALLING stop");
        _tid.send(Control.STOP);
        receive((Control control) =>
                check(control is Control.END, "Bad something")
            );
    }
    static void run(string task_name, Params args) nothrow {
        assumeWontThrow(writeln("CALLING run"));
        try {
            pragma(msg, "---- run start");
            pragma(msg, Params);
            pragma(msg, ParamNames);
            alias f=Func;
            pragma(msg, isFunction!Func);
            pragma(msg, isDelegate!Func);
            pragma(msg, is(Func == function));
            pragma(msg, isFunctionPointer!Func);
            pragma(msg, "---- run stop");
            // pragma(msg, isPointer!Func);
            scope(success) {
                assumeWontThrow(
                    writefln("Success")
                    );
            }
            scope(failure) {
                assumeWontThrow(
                    writefln("Fail")
                    );
            }
            version(none) {
                log.register(task_name);
            }
            Func task;
            // Boiler coded
            assumeWontThrow(writeln(format("run: call task '%s' with params ", task_name)));
            assumeWontThrow(writeln(args));
            task(args);
        }
        catch (Exception e) {
            assumeWontThrow(
                writefln("%s", e)
                );
        }
    }
}

mixin template TaskBasic() {
    import concurrency=std.concurrency;
    bool stop;
    @TaskMethod void control(immutable(Control) control) {
        writeln("CALLING task.control");
        writeln("received control: ", control);
        with(Control) {
            final switch(control) {
            case STOP:
                ownerTid.send(Control.END);
                break;
            case LIVE:
                /// Should throw something
                break;
            case END:
                stop = true;
            }
        }
    }
    // static void taskReceive(Args...)(Args args) {
    //     writeln("CALLING task.taskReceive");
    //     concurrency.receive(&control, args);
    // }
}

struct SomeTask {
    import std.concurrency;
    mixin TaskBasic;
    @TaskMethod somename(string name) {
        writeln("call somename: ", name);
    }
    @TaskMethod some_othername(int name, string s, double d) {
        writeln("call some_othername: ", name, s, d);
    }
    // This is the task !!
    void opCall(int x, uint y) {
        writeln("CALLING task.opCall");
        writefln("Result %s", 2*x*y);
        while(!stop) {
            receive(
                &control,
                &somename,
                &some_othername);
        }
    }
}
unittest {
    // TODO
    alias some_task=Task!SomeTask;
    auto task=some_task("task_name", 10, 20);
    //task.somename("send some text");
    //task.some_othername(10, "a", 2.5); 
    task.control_dummy(Control.END);
}