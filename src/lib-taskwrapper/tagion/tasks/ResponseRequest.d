module tagion.tasks.ResponseRequest;

import concurrency=std.concurrency;
import std.concurrency : Tid, ownerTid, register, thisTid, spawn, send;
import std.stdio;
import std.exception : assumeWontThrow;
import std.typecons : Typedef, Tuple;


//alias ResponseRequest=ResponseRequestT!void;

@safe
struct ResponseRequestT(T) {
    protected alias _ID=Typedef!(uint, uint.init, T.stringof);
    @safe
    static _ID new_count() @nogc nothrow  {
        static _ID id_count;
        id_count++;
        if (id_count is id_count.init) {
            id_count = id_count.init + 1;
        }
        return id_count;
    }
    string task_name;
    _ID id;
    alias ID=immutable(_ID);
    this(string task_name) immutable nothrow {
        this.task_name = task_name;
        id=new_count;
    }
    static void send(Args...)(Tid tid, string task_name, Args args) @trusted {
        immutable resp=new immutable(ResponseRequestT)(task_name);
        writefln("%s %s %s", task_name, args, typeof(resp).stringof);
        concurrency.send(tid, resp, args);
    }
    void reply(T)(T message) immutable @trusted {
        auto tid = concurrency.locate(task_name);
        writefln("id=%s message=%s", id, message);
        tid.send(id, message);
    }

    static if (is(T == void)) {
        alias Message=immutable(ResponseRequestT)*;
    }
    else {
        alias Message=Tuple!(immutable(ResponseRequestT)*, "response",  T, "value");
    }
    alias Cache = Message[ID];
}


unittest {
    import tagion.basic.Types : Control;
    import std.algorithm : each;
    import std.format;
    import core.time;
    import std.stdio;
    alias ResponseText=ResponseRequestT!string;
    static void task1(string task_name) {
        bool stop;
        task_name.register(thisTid);
        scope(exit) {
            ownerTid.send(Control.END);
        }
        void do_stop(Control ctrl) {
            if (ctrl is Control.STOP) {
                stop = true;
            }
        }
        // alias XXX=ResponseRequest.Message!(string);
        // XXX[] xxx;
        // XXX[uint] cache;
        ResponseText.Cache cache;
//        string[ResponseRequest.ID] echos;
//        immutable(ResponseRequest*)
        pragma(msg, "!!!!!!!!!!!!!!!!", ResponseText.Message);
        void request(immutable(ResponseText)* resp, string echo) {
            assert(!(resp.id in cache));
            cache[resp.id]=ResponseText.Message(resp, echo); //.message(echo);
//            echos[resp.id]=echo;
            writefln("cache[resp.id] %d", resp.id);
            writefln("cache[resp.id] %x", resp.task_name.ptr);
            writefln("cache[resp.id] %d", resp.task_name.length);
            writefln("cache[resp.id] %s", resp.task_name);
//            writefln("cache[resp.id] %x", cache[resp.id].resp);
//            writefln("cache[resp.id].resp.response_task_name.ptr %x", cache[resp.id].task_name.ptr);
        }
        ownerTid.send(Control.LIVE);
        while(!stop) {
            const time_out=concurrency.receiveTimeout(
                100.msecs,
                &do_stop,
                &request
                );
            if (time_out) {
                writefln("Timeout %d", cache.length);

                foreach(a; cache.byValue) {
                    writeln("------ --------");
//                    writefln("'%s' %s",a.message, format("response %s", a.id));
                    writefln("a.resp.id %d",a.response.id);
                    writefln("a.resp.response_task_name.length %d",a.response.task_name.length);
                    writefln("a.resp.response_task_name.ptr %x",a.response.task_name.ptr);
//                    writefln("a.resp.response_task_name %x",&(a.resp.response_task_name[0]));
                    a.response.reply(format("response %s", a.response.id));
                }
                // cache.byValue
                //     .each!((a) => a.response(a.message, format("response %s", a.id))s);
                cache.clear;
            }
        }
    }
    static void task2_1(string task_name) {
        bool stop;
        scope(exit) {
            ownerTid.send(Control.END);
        }
        task_name.register(thisTid);
        void do_stop(Control ctrl) {
            if (ctrl is Control.STOP) {
                stop = true;
            }
        }
        ownerTid.send(Control.LIVE);
        while(!stop) {
            concurrency.receive(
                &do_stop
                );
        }
    }
    static void task2(string task_name) {
        bool stop;
        task_name.register(thisTid);
        scope(exit) {
            ownerTid.send(Control.END);
        }
        auto tid=spawn(&task2_1, task_name~"_child");
        assert(concurrency.receiveOnly!Control is Control.LIVE);
        void do_stop(Control ctrl) {
            if (ctrl is Control.STOP) {
                tid.send(Control.STOP);
                assert(concurrency.receiveOnly!Control == Control.END);
                stop = true;
            }
        }
        ownerTid.send(Control.LIVE);
        while(!stop) {
            concurrency.receive(
                &do_stop
                );
        }
    }
    enum task1_name="task1";
    auto task1_tid=spawn(&task1, task1_name);
    assert(concurrency.receiveOnly!Control is Control.LIVE);
    // auto task2_tid=spawn(&task1, "task2");
    // assert(concurrency.receiveOnly!Control is Control.LIVE);

    string main_task="main";
    concurrency.register(main_task, thisTid);
//    immutable request=immutable(ResponseRequest)(main_task);
    enum num=6;
    foreach(i; 0..num) {
        ResponseText.send(task1_tid, main_task, format("echo %d", i));
    }
    writefln("Wait for response");
    foreach(i; 0..num) {
        writefln("%s ", concurrency.receiveOnly!(ResponseText.ID, string));
    }
    task1_tid.send(Control.STOP);
    assert(concurrency.receiveOnly!Control == Control.END);
    // task2_tid.send(Control.STOP);
    // assert(concurrency.receiveOnly!Control == Control.END);



}
