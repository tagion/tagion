module tagion.tasks.ResponseRequest;

import concurrency = std.concurrency;
import std.concurrency : Tid, ownerTid, register, thisTid, spawn, send;
import std.stdio;
import std.exception : assumeWontThrow;
import std.typecons : Typedef, Tuple;
import std.traits : isType;

//alias ResponseRequest=ResponseRequestT!void;

@safe
struct ResponseRequest(alias Cookie) {
    static if (isType!Cookie) {
        enum cookie = Cookie.stringof;
    }
    else static if (is(typeof(Cookie) == string)) {
        enum cookie = Cookie;
    }
    else {
        static assert(0, format("Invalid cookie %s ", Cookie.stringof));
        enum cookie = "Invalid";
    }

    alias ID = Typedef!(uint, uint.init, cookie);
    @safe
    static ID new_count() @nogc nothrow {
        static ID id_count;
        id_count++;
        if (id_count is id_count.init) {
            id_count = id_count.init + 1;
        }
        return id_count;
    }

    string task_name;
    ID id;
    alias iID = immutable(ID);
    this(string task_name) immutable nothrow {
        this.task_name = task_name;
        id = new_count;
    }

    static ID send(Args...)(Tid tid, string task_name, Args args) @trusted {
        immutable resp = new immutable(ResponseRequest)(task_name);
        concurrency.send(tid, resp, args);
        return resp.id;
    }

    void reply(T)(T message) immutable @trusted {
        auto tid = concurrency.locate(task_name);
        tid.send(id, message);
    }

    static if (isType!Cookie) {
        static if (is(Cookie == void)) {
            alias Message = immutable(ResponseRequest)*;
        }
        else {
            alias Message = Tuple!(immutable(ResponseRequest)*, "response", Cookie, "message");
        }
        alias Cache = Message[ID];
    }
}

enum isResponseRequest(T) = __traits(hasMember, T, "ID") && __traits(hasMember, T, "task_name");

mixin template Cache(R, T) if (isResponseRequest!R) {
    static if (is(Cookie == T)) {
        alias Message = immutable(R)*;
    }
    else {
        alias Message = Tuple!(immutable(R)*, "response", T, "message");
    }
    alias Cache = Message[ID];
}

unittest {
    import tagion.basic.Types : Control;
    import std.exception : assertThrown, assertNotThrown;
    import std.algorithm : each;
    import std.format;
    import std.stdio;
    import std.random;
    import core.time;
    import core.thread : Thread;

    auto rnd = Random(unpredictableSeed);

    alias ResponseText = ResponseRequest!string;
    @safe @nogc
    static bool doThis(Tid tid) pure nothrow {
        assert(0);
    }

    concurrency.setMaxMailboxSize(thisTid, size_t(0), &doThis); //size_t messages, bool function(Tid) onCrowdingDoThis);
    static void task1(string task_name) {
        int count_down = 10;
        bool stop;
        task_name.register(thisTid);
        scope (exit) {
            ownerTid.send(Control.END);
        }
        void do_stop(Control ctrl) {
            if (ctrl is Control.STOP) {
                stop = true;
            }
        }

        ResponseText.Cache cache;
        void request(immutable(ResponseText)* resp, string echo) {
            cache[resp.id] = ResponseText.Message(resp, echo); //.message(echo);
        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            const message_received = concurrency.receiveTimeout(
                    100.msecs,
                    &do_stop,
                    &request
            );

            if (!message_received || ((cache.length + 1) % 4 == 0)) {
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

    alias childFormat = format!("child %s", string);
    static void task2(string task_name) {
        int count_down = 10;
        bool stop;
        task_name.register(thisTid);
        scope (exit) {
            ownerTid.send(Control.END);
        }
        auto child_tid = spawn(&task1, task_name ~ "_child");
        assert(concurrency.receiveOnly!Control is Control.LIVE);
        void do_stop(Control ctrl) {
            if (ctrl is Control.STOP) {
                child_tid.send(Control.STOP);
                assert(concurrency.receiveOnly!Control == Control.END);
                stop = true;
            }
        }

        ResponseText.Cache cache;
        void request(immutable(ResponseText)* resp, string echo, bool to_child) {
            if (to_child) {
                child_tid.send(resp, childFormat(echo));
                return;
            }
            cache[resp.id] = ResponseText.Message(resp, echo); //.message(echo);

        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            const message_received = concurrency.receiveTimeout(
                    50.msecs,
                    &do_stop,
                    &request,
            );
            if (!message_received || ((cache.length + 1) % 4 == 0)) {
                count_down--;
                if (count_down < 0) {
                    ownerTid.send("Fail to finish the test from parent");
                    stop = true;
                }
                cache.byValue
                    .each!((a) => a.response.reply(a.message));
                cache.clear;
            }
        }
    }

    enum task1_name = "task1";
    auto task1_tid = spawn(&task1, task1_name);
    assert(concurrency.receiveOnly!Control is Control.LIVE);

    string main_task = "main";
    concurrency.register(main_task, thisTid);

    { // Simple response text
        enum num = 11;
        ResponseText.ID[string] message_list;
        foreach (i; 0 .. num) {
            auto msg = format("echo %d", i);
            message_list[msg] = ResponseText.send(task1_tid, main_task, msg);
        }
        assert(message_list.length is num);
        foreach (i; 0 .. num) {
            concurrency.receive(
                    (ResponseText.iID id, string message) {
                const received_id = message_list.get(message, id.max);
                assert(received_id is id);
                message_list.remove(message);
            },
                    (string error) { assert(0, error); });

        }
        assert(message_list.length == 0);
    }

    task1_tid.send(Control.STOP);
    assert(concurrency.receiveOnly!Control == Control.END);
    enum task2_name = "task2";
    auto task2_tid = spawn(&task2, task2_name);
    assert(concurrency.receiveOnly!Control is Control.LIVE);
    { /// Send response for both child and parent
        enum num = 21;
        ResponseText.ID[string] message_list;
        foreach (i; 0 .. num) {
            bool to_child = uniform!"[]"(0, 1, rnd) == 1;
            const msg = format("echo %d", i);
            const result_msg = (to_child) ? childFormat(msg) : msg;
            immutable resp = new immutable(ResponseText)(main_task);
            message_list[result_msg] = ResponseText.send(task2_tid, main_task, msg, to_child);
        }
        assert(message_list.length is num);
        foreach (i; 0 .. num) {
            concurrency.receive(
                    (ResponseText.iID id, string message) {
                const received_id = message_list.get(message, id.max);
                assert(received_id is id);
                message_list.remove(message);
            },
                    (string error) { assert(0, error); });
        }
        assert(message_list.length == 0);
    }
    task2_tid.send(Control.STOP);
    assert(concurrency.receiveOnly!Control == Control.END);
}
