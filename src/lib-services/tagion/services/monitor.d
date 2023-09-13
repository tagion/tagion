module tagion.services.monitor;

import std.format;
import std.socket;
import core.thread;
import tagion.utils.pretend_safe_concurrency;

import tagion.logger.Logger;
import tagion.actor;
import tagion.basic.tagionexceptions : TagionException;
import tagion.actor.exceptions;

import tagion.hibon.Document;
import tagion.utils.JSONCommon;
import tagion.basic.Types : FileExtension;
import tagion.network.ListenerSocket;

@safe
struct MonitorOptions {
    bool enable = false; /// When enabled the Monitor is started
    ushort port = 10900; /// Monitor port
    uint timeout = 500; ///.service.server.listerne timeout in msecs
    FileExtension dataformat = FileExtension.json;
    string url="127.0.0.1";
    string taskname = "monitor";
    mixin JSONCommon;
}



void monitorServiceTask(immutable(MonitorOptions) opts) @trusted nothrow {
    try {

        // ownerTid.send(Ctrl.STARTING);
        log.register(opts.taskname);


        log("SockectThread port=%d addresss=%s", opts.port, opts.url);

        auto listener_socket = ListenerSocket("127.0.0.1",
                opts.port, opts.timeout, opts.taskname);
        auto listener_socket_thread = listener_socket.start;

        scope (exit) {
            listener_socket.stop;
        }

        // bool stop;
        // void handleState(Sig ts) {
        //     with (Sig) switch (ts) {
        //     case STOP:
        //         log("Kill socket thread. %d", opts.port);

        //         stop = true;
        //         break;
        //     default:
        //         log.error("Bad Control command %s", ts);
        //     }
        // }

        void taskfailure(immutable(TaskFailure) t) @safe {
            ownerTid.send(t);
        }

        ownerTid.send(Ctrl.ALIVE);
        while (!thisActor.stop) {
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

        log("%s", t);
        fatal(t);
    }
}