module tagion.actor.Actor;

import std.algorithm.searching : any;
import std.format;
import std.traits;
import std.meta;

alias Tid = concurrency.Tid;
import concurrency = std.concurrency;
import tagion.basic.Types : Control;
import tagion.basic.TagionExceptions : fatal, Check, TagionException;
import tagion.logger.Logger;
import tagion.hibon.ActorException;



@safe
struct method {
}

@safe
struct local {
}

@safe
struct task {
}


template isProtected(This, string name) {
    static if (__traits(compiles, __traits(getVisibility, __traits(getMember, This, name)))) {
        enum isProtected = __traits(getVisibility, __traits(getMember, This, name)) == q{protected};
    }
    else {
        enum isProtected = true;
    }
}

enum isTrue(alias eval) = __traits(compiles, eval) && eval;

enum isUDA(This, string name, UDA) = isTrue!(hasUDA!(__traits(getMember, This, name), UDA));

enum isTask(This, string name) = isUDA!(This, name, task); //isTrue!(hasUDA!(__traits(getMember, This, name), task));

enum isMethod(This, string name) = isUDA!(This, name, method);

enum isCtorDtor(This, string name) =  ["__ctor", "__dtor"].any!(a => a == name);


template allMethodFilter(This, alias pred) {
    template Filter(string[] members) {
        static if (members.length is 0) {
            enum Filter = [];
        }
        else static if (members.length is 1) {
            static if (pred!(This, members[0])) {
                enum Filter = [members[0]];
            }
            else {
                enum Filter = [];
            }
        }
        else {
            enum Filter = Filter!(members[0..$/2]) ~ Filter!(members[$/2..$]);
        };
    }
    enum allMembers = [__traits(allMembers, This)];
    enum allMethodFilter = Filter!(allMembers);
}


mixin template TaskActor() {
//    import concurrency = std.concurrency;
    import core.time : Duration;
    import tagion.actor.Actor;
    import tagion.basic.Types : Control;

    bool stop;
    @method void control(Control ctrl) {
        stop = (ctrl is Control.STOP);
        writefln("control stop %s", stop);
    }

    @method @local void fail(immutable(Exception) e) @trusted {
        stop = true;
        concurrency.prioritySend(concurrency.ownerTid, e);
    }

    void stopAll() @trusted {
        foreach(ref tid; tids.byValue) {
            tid.send(Control.STOP);
            assert(concurrency.receiveOnly!Control is Control.END,
                format("Failed when stopping all child actors for Actor %s", This.stringof));
        }
    }

    void alive() @trusted {
        send(concurrency.ownerTid, Control.LIVE);
    }


    void end() @trusted {
        send(concurrency.ownerTid, Control.END);
    }

alias This = typeof(this);
    void receive() @trusted {
        enum actor_methods = allMethodFilter!(This, isMethod);
        pragma(msg, "actor_methods ", actor_methods);
        enum code = format("concurrency.receive(%-(&%s, %));", actor_methods);
        pragma(msg, "code ", code);
        mixin(code);
    }

    bool receiveTimeout(Duration duration) @trusted {
        enum actor_methods = allMethodFilter!(This, isMethod);
        pragma(msg, "actor_methods ", actor_methods);
        enum code = format("return concurrency.receiveTimeout(duration, %-(&%s, %));", actor_methods);
        pragma(msg, "code ", code);
        mixin(code);
    }
}

private static Tid[string] tids;

bool isRunning(string taskname) @trusted {
    if (taskname in tids) {
        return concurrency.locate(taskname) != Tid.init;
    }
    return false;
}

protected static string generateAllMethods(alias This)()
{
    import std.array : join;

    string[] result;
    static foreach (m; __traits(allMembers, This))
    {
        {
            enum code = format!(q{alias Func=This.%s;})(m);
            mixin(code);
            static if (isCallable!Func && hasUDA!(Func, method))
            {
                static if (!hasUDA!(Func, local)) {
                    enum method_code = format!q{
                        alias FuncParams_%1$s=AliasSeq!%2$s;
                        void %1$s(FuncParams_%1$s args) @trusted {
                            concurrency.send(tid, args);
                        }}(m, Parameters!(Func).stringof);
                    result ~= method_code;
                }
                    //}
            }
        }
    }
    return result.join("\n");
}

@safe
auto actor(Task, Args...)(Args args) if (is(Task == class) || is(Task == struct)) {
    import concurrency = std.concurrency;
    static struct ActorFactory {
        enum public_members =  allMethodFilter!(Task, templateNot!isProtected);
        enum task_members = allMethodFilter!(Task, isTask);
        pragma(msg, "task_members ", task_members);
        static assert(task_members.length !is 0, format("%s is missing @task (use @task UDA to mark the member function)", Task.stringof));
        static assert(task_members.length is 1, format("Only one member of %s must be mark @task", Task.stringof));
        enum task_func_name = task_members[0];
        alias TaskFunc = typeof(__traits(getMember, Task, task_func_name));
        alias Params = Parameters!TaskFunc;
        alias ParamNames = ParameterIdentifierTuple!TaskFunc;
        pragma(msg, "Params ", Params);
        protected static void run(string task_name, Params args) nothrow {
            try {
                static if (is(Task == struct)) {
                    Task task;
                }
                else {
                    Task task = new Task;
                }
                scope(success) {
                    writefln("STOP Success");
                    task.stopAll;
                    writeln("Stop all");
                    tids.remove(task_name);
                    writefln("Remove %s ", task_name);
                    task.end;
                    //prioritySend(concurrency.ownerTid, Control.END);

                }
                const task_func = &__traits(getMember, task, task_func_name);
                log.register(task_name);
                task_func(args);

            }
            catch (Exception e) {
                fatal(e);
            }
        }
        @safe
        struct Actor {
            Tid tid;
            void stop() @trusted {
                concurrency.send(tid, Control.STOP);
                .check(concurrency.receiveOnly!(Control) is Control.END, format("Expecting to received and %s after stop", Control.END));
            }
            void halt() @trusted {
                concurrency.send(tid, Control.STOP);
            }

            // enum methods = allMethodFilter!(Task, isMethod);
            // pragma(msg, "!!!Methods ", methods);
            // pragma(msg, generateAllMethods!(Task));
            enum members_code = generateAllMethods!(Task);
            pragma(msg, members_code);
            mixin(members_code);
        }
        /**

         */
        auto opCall(Args...)(string taskname, Args args) @trusted {
            import std.meta : AliasSeq;
            import std.typecons;
            alias FullArgs = Tuple!(AliasSeq!(string, Args));
            auto full_args = FullArgs(taskname, args);
            .check(concurrency.locate(taskname) == Tid.init, format("Actor %s has already been started", taskname));
            auto tid = tids[taskname] = concurrency.spawn(&run, full_args.expand);
            return Actor(tid);
        }
    }
    ActorFactory result;
    return result;
}

version(unittest) {
    import std.stdio;
    import core.time;
    private {
        void send(Args...)(Tid tid, Args args) @trusted {
            concurrency.send(tid, args);
        }
        auto receiverOnly(Args...)(Tid tid, Args args) @trusted {
            return concurrency.receiveOnly(tid, args);
        }
    }
}

@safe
unittest {
    import std.stdio;
    @safe
    static struct MyActor {
        // protected {
            // HashGraph hashgraph;
        int count;
        string some_name;
        @method void some(string str) { // reciever
            writefln("SOME %s ", str);
            some_name = str;
        }

        @method void decrease(int by) {
            count -= by;
        }
        version(none) {

        enum get {
            Yes,
            No,
        }

        @method void getSome(get str) @trusted { // reciever

            ownerTid.send(some_name);
        }
        }
        mixin TaskActor;

        @task void runningTask(int label) {
            count = label;
            writefln("Alive!!!!");
            alive; // Task is now alive
            while (!stop) {
                receiveTimeout(100.msecs);
                writefln("Waiting to stop");
                // const rets=receiverMethods(100.msec);
            }
        }
    }

    //alias fail = MyActor.fail;
    //pragma(msg, "fail ", fail.stringof);
    //pragma(msg, "getUDAs!(Func, method)[0] ", getUDAs!(fail, method)[0].access);

    auto my_actor_factory = actor!MyActor;
    /// Test of a single actor
    {
        enum single_actor_taskname = "task_name_for";
        assert(!isRunning(single_actor_taskname));
        // Starts one actor of MyActor
        auto my_actor_1 = my_actor_factory(single_actor_taskname, 10);
        scope(exit) {
            // Stop and wait of the task to end
            my_actor_1.stop;
//            assety
        }

        {
            //
            my_actor_1.some("Some text");
            my_actor_1.stop;
        }
    }
}
