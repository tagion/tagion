module tagion.tasks.ResponseRequest;

import concurrency=std.concurrency;
import std.concurrency : Tid, ownerTid, register, thisTid, spawn, send;



@safe
struct ResponseRequest {
    void send(Args...)(Tid tid, immutable(ResponseRequest) request, Args args) @trusted {
        concurrency.send(tid, request, args);
    }
    string response_task_name;
    uint id;
    immutable(ResponseRequest*) cascade;
    @disable this();
    this(string task_name) immutable nothrow {
        id_count++;
        id=new_count;
        cascade=null;
    }
    this(string task_name, immutable(ResponseRequest*) cascade) immutable nothrow {
        id_count++;
        id=cascade.id;
        this.cascade = cascade;
    }
    static uint id_count;
    static uint new_count() @nogc nothrow {
        id_count++;
        if (id_count is id_count.init) {
            id_count = id_count.init + 1;
        }
        return id_count;
    }
    void opCall(T)(string task_name, immutable(T) msg) immutable @trusted {
        if (this !is this.init) {
            auto tid = concurrency.locate(response_task_name);
            concurrency.send(tid, task_name, id, msg);
        }
    }

    immutable(Message!T*) message(T)(T x) immutable pure nothrow {
        return new immutable(Message!T)(&this, x);
    }

    alias MessageType(T) = immutable(Message!T)*;

    @safe
    struct Message(T) {
        immutable(ResponseRequest*) resp;
        T message;
        this(immutable(ResponseRequest*) resp, T message) immutable pure nothrow {
            this.resp=resp;
            this.message = message;
        }
        uint id() immutable pure nothrow {
            return resp.id;
        }
        void response(Args...)(Args args) immutable @trusted {
            auto tid=concurrency.locate(resp.response_task_name);
            concurrency.send(tid, args);
            // if (cascade !is null) {
        //     auto cascade_tid = concurrency.locate(cascade.response_task_name);
        //     cascade_tid.send(args);
        // }
        }
    }
}


unittest {
    import tagion.basic.Types : Control;
    import std.algorithm : each;
    import std.format;
    import core.time;
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
        ResponseRequest.MessageType!(string)[uint] cache;
        void request(immutable(ResponseRequest) resp, string echo) {
            assert(!(resp.id in cache));
            cache[resp.id]=resp.message(echo);
        }
        ownerTid.send(Control.LIVE);
        while(!stop) {
            const time_out=concurrency.receiveTimeout(
                100.msecs,
                &do_stop,
                &request
                );
            if (time_out) {
                foreach(a;cache.byValue) {
                    a.response(format("response %s", a.id));
                }

                // cache.byValue
                //     .each!((a) => a.response(format("response %s", a.id)));
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
    auto task1_tid=spawn(&task1, "task1");
    assert(concurrency.receiveOnly!Control is Control.LIVE);
    auto task2_tid=spawn(&task1, "task2");
    assert(concurrency.receiveOnly!Control is Control.LIVE);

    task1_tid.send(Control.STOP);
    assert(concurrency.receiveOnly!Control == Control.END);
    task2_tid.send(Control.STOP);
    assert(concurrency.receiveOnly!Control == Control.END);



}
