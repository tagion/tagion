module tagion.services.monitor;

import core.thread;
import std.format;
import std.socket;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.basic.Types : FileExtension;
import tagion.basic.tagionexceptions : TagionException;
import tagion.hibon.Document;
import tagion.logger.Logger;
import tagion.network.ListenerSocket;
import tagion.utils.JSONCommon;
import tagion.utils.pretend_safe_concurrency;

@safe
struct MonitorOptions {
    bool enable = false; /// When enabled the Monitor is started
    ushort port = 10900; /// Monitor port
    uint timeout = 500; ///.service.server.listerne timeout in msecs
    FileExtension dataformat = FileExtension.json;
    string url = "127.0.0.1";
    string taskname = "monitor";
    mixin JSONCommon;
}

void monitorServiceTask(immutable(MonitorOptions) opts) @trusted nothrow {
    try {
        // setState(Ctrl.STARTING);
        // scope (exit) {
        //     setState(Ctrl.END);
        // }

        log.task_name = opts.taskname;

        log("SockectThread port=%d addresss=%s", opts.port, opts.url);
        auto listener_socket = ListenerSocket(opts.url,
                opts.port, opts.timeout, opts.taskname);
        auto listener_socket_thread = listener_socket.start;

        scope (exit) {
            listener_socket.stop;
        }

        void taskfailure(immutable(TaskFailure) t) @safe {
            ownerTid.send(t);
        }

        setState(Ctrl.ALIVE);
        while (!thisActor.stop) {
            pragma(msg, "REV: Should the 500.msecs be an opts");
            receiveTimeout(500.msecs, //Control the thread
                    &signal,
                    &ownerTerminated,
                    (string json) @trusted { listener_socket.broadcast(json); },
                    (immutable(ubyte)[] hibon_bytes) @trusted { listener_socket.broadcast(hibon_bytes); },
                    (Document doc) @trusted { listener_socket.broadcast(doc); },
                    &taskfailure
            );
        }
    }
    catch (Throwable t) {
        import std.stdio;

        fail(t);
    }
}
