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
    @TaskMethod void control(immutable(Control) control) {
        with(Control) {
            final switch(control) {
            case STOP:
                stop = true;
                break;
            case LIVE:
                /// Should throw something
                break;
            case END:
                // If the task can spawn another tasks then it could receive LIVE and END
            }
        }
    }
}

struct SomeTask {
    import std.concurrency;
    mixin TaskBasic;
    @TaskMethod void somename(string name) {
        writeln("call somename: ", name);
    }
    @TaskMethod void some_othername(int name, string s, double d) {
        writeln("call some_othername: ", name, s, d);
    }

    // This method is the task itself
    void opCall(int x, uint y) {
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
    // tests for TaskWrapper
}