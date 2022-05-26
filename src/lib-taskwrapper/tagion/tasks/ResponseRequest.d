module tagion.tasks.ResponseRequest;

import concurrency=std.concurrency;
import std.concurrency : Tid, ownerTid, register, thisTid, spawn, send;
import std.stdio;
import std.exception : assumeWontThrow;
import std.typecons : Typedef, Tuple;


//alias ResponseRequest=ResponseRequestT!void;

@safe
struct ResponseRequestT(T) {
    alias ID=Typedef!(uint, uint.init, T.stringof);
    @safe
    static ID new_count() @nogc nothrow  {
        static ID id_count;
        id_count++;
        if (id_count is id_count.init) {
            id_count = id_count.init + 1;
        }
        return id_count;
    }
    string task_name;
    ID id;
    alias iID=immutable(ID);
    this(string task_name) immutable nothrow {
        this.task_name = task_name;
        id=new_count;
    }
    static ID send(Args...)(Tid tid, string task_name, Args args) @trusted {
        immutable resp=new immutable(ResponseRequestT)(task_name);
        writefln("%s %s resp.id=%d", task_name, args, resp.id);
        concurrency.send(tid, resp, args);
        return resp.id;
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
        alias Message=Tuple!(immutable(ResponseRequestT)*, "response",  T, "message");
    }
    alias Cache = Message[ID];
}


unittest {
    import tagion.basic.Types : Control;
    import std.exception : assertThrown, assertNotThrown;
    import std.algorithm : each;
    import std.format;
    import std.stdio;
    import core.time;
    import core.thread : Thread;
    alias ResponseText=ResponseRequestT!string;
    @safe @nogc
    static bool doThis(Tid tid) pure nothrow {
        assert(0);
    }
    concurrency.setMaxMailboxSize(thisTid, size_t(0), &doThis); //size_t messages, bool function(Tid) onCrowdingDoThis);
    static void task1(string task_name) {
        int count_down = 10;
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
        ResponseText.Cache cache;
        void request(immutable(ResponseText)* resp, string echo) {
            cache[resp.id]=ResponseText.Message(resp, echo); //.message(echo);
            writefln("resp.id %d cache.length=%d", resp.id, cache.length);
        }
        ownerTid.send(Control.LIVE);
        while(!stop) {
            const message_received=concurrency.receiveTimeout(
                100.msecs,
                &do_stop,
                &request
                );

            if (!message_received || ((cache.length+1) % 4 == 0)) {
                writefln("\nTimeout %d count_down=%d", cache.keys.length, count_down);
                count_down--;
                if (count_down < 0) {
                    ownerTid.send("Fail to finish the test");
                    stop = true;
                }

                cache.byValue
                     .each!((a) => a.response.reply(a.message));
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
//    assumeWontThrow({

    { // Simple resonse text
        enum num=11;
        ResponseText.ID[string] message_list;
        pragma(msg, "ResponseText.ID ", ResponseText.ID);
        foreach(i; 0..num) {
            writefln("i=%d",i);
            // if (i % 3 == 0) {
            //     Thread.sleep(20.msecs);
            // }
            auto msg=format("echo %d", i);
            message_list[msg]=ResponseText.send(task1_tid, main_task, msg);
        }
        assert(message_list.length is num);
        writefln("Wait for response %s", message_list);
        foreach(i; 0..num) {
            writefln("Receive loop %d", i);
            concurrency.receive(
                (ResponseText.iID id, string message) {
                    //immutable received_message =concurrency.receiveOnly!(immutable(ResponseText.ID), string); //ResponseText.Message);
                    writefln("...id=%d %s ", id, message); //concurrency.receiveOnly!(ResponseText.ID, string));
                    const received_id=message_list.get(message, id.max);
                    writefln("received_id=%d id=%d", received_id, id);
                    assert(received_id is id);
                    message_list.remove(message);
                },
                 (string error) {
                     assert(0, error);
                 });

        }
        assert(message_list.length == 0);
    }

    task1_tid.send(Control.STOP);
    assert(concurrency.receiveOnly!Control == Control.END);
    // task2_tid.send(Control.STOP);
    // assert(concurrency.receiveOnly!Control == Control.END);



}
