module tagion.tasks.ResponseRequest;

import std.concurrency;

struct ResponseRequest {
    string response_task_name;
    uint id;
    immutable(ResponseRequest*) cascade;
    @disable this();
    this(string task_name) immutable nothrow {
        id_count++;
        id=new_count;
        cascade=null;
    }
    this(string task_name, ref immutable(ResponseRequest) cascade) immutable nothrow {
        id_count++;
        id=cascade.id;
        this.cascade = &cascade;
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
            auto tid = locate(response_task_name);
            tid.send(task_name, id, msg);
        }
    }
    void response(Args...)(Args args) immutable @trusted {
        if (cascade !is null) {
            auto tid = locate(cascade.response_task_name);
            tid.send(args);
        }
    }
}

unittest {
    import tagion.basic.Types : Control;
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
        ownerTid.send(Control.LIVE);
        while(!stop) {
            receive(
                &do_stop
                );
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
            receive(
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
        assert(receiveOnly!Control is Control.LIVE);
        void do_stop(Control ctrl) {
            if (ctrl is Control.STOP) {
                tid.send(Control.STOP);
                assert(receiveOnly!Control == Control.END);
                stop = true;
            }
        }
        ownerTid.send(Control.LIVE);
        while(!stop) {
            receive(
                &do_stop
                );
        }
    }
    auto task1_tid=spawn(&task1, "task1");
    assert(receiveOnly!Control is Control.LIVE);
    auto task2_tid=spawn(&task1, "task2");
    assert(receiveOnly!Control is Control.LIVE);

    task1_tid.send(Control.STOP);
    assert(receiveOnly!Control == Control.END);
    task2_tid.send(Control.STOP);
    assert(receiveOnly!Control == Control.END);


}
