/// Services to handle remote view of the HashGraph
module tagion.prior_services.MonitorService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;

import tagion.logger.Logger;
import tagion.prior_services.Options : Options, setOptions, options;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Types : Control;
import tagion.basic.basic : basename;
import tagion.basic.tagionexceptions : TagionException;
import tagion.crypto.Types : Pubkey;

import tagion.hibon.Document;
import tagion.network.ListenerSocket;
import tagion.basic.tagionexceptions;

//Create flat webserver start class function - create Backend class.
void monitorServiceTask(immutable(Options) opts) nothrow {
    try {

        immutable task_name = opts.monitor.task_name;
        log.register(task_name);

        scope (success) {
            ownerTid.prioritySend(Control.END);
        }

        // Set thread global options
        setOptions(opts);

        log("SockectThread port=%d addresss=%s", opts.monitor.port, commonOptions.url);

        auto listener_socket = ListenerSocket("127.0.0.1",
                opts.monitor.port, opts.monitor.timeout, opts.monitor.task_name);
        auto listener_socket_thread = listener_socket.start;

        scope (exit) {
            listener_socket.stop;
        }

        bool stop;
        void handleState(Control ts) {
            with (Control) switch (ts) {
            case STOP:
                log("Kill socket thread. %d", opts.monitor.port);

                stop = true;
                break;
            default:
                log.error("Bad Control command %s", ts);
            }
        }

        void taskfailure(immutable(TaskFailure) t) {
            ownerTid.send(t);
        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            receiveTimeout(500.msecs, //Control the thread
                    &handleState,
                    (string json) { listener_socket.broadcast(json); },
                    (immutable(ubyte)[] hibon_bytes) { listener_socket.broadcast(hibon_bytes); },
                    (Document doc) { listener_socket.broadcast(doc); },
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
