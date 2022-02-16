module tagion.services.MonitorService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;

import tagion.logger.Logger;
import tagion.services.Options : Options, setOptions, options;
import tagion.options.CommonOptions : commonOptions;
import tagion.basic.Basic : Control, basename, Pubkey;
import tagion.basic.TagionExceptions : TagionException;

import tagion.hibon.Document;
import tagion.network.ListenerSocket;
import tagion.basic.TagionExceptions;

//Create flat webserver start class function - create Backend class.
void monitorServiceTask(immutable(Options) opts) nothrow {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }

        // Set thread global options
        setOptions(opts);
        immutable task_name = opts.monitor.task_name;
        log.register(task_name);

        log("SockectThread port=%d addresss=%s", opts.monitor.port, commonOptions.url);

        auto listener_socket = ListenerSocket(commonOptions.url,
                opts.monitor.port, opts.monitor.timeout, opts.monitor.task_name);
        auto listener_socket_thread = listener_socket.start;

        scope (exit) {
            log("In exit of soc. port=%d th", opts.monitor.port);
            listener_socket.stop;

            version (none)
                if (listener_socket_thread !is null) {
                    //  listener_socket.close;
                    listener_socket.stop;

                    log("Kill listener socket. %d", opts.monitor.port);
                    //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.
                    //            if ( ldo.active ) {
                    auto ping = new TcpSocket(new InternetAddress(opts.url, opts.monitor.port));
                    //                receive( &handleClient);
                    writefln("Pause for %d to close", opts.monitor.port);
                    Thread.sleep(500.msecs);
                    // run_listener = false;
                    log("run_listerner %s %s", listener_socket.active, opts.monitor.port);
                    //            }
                    writefln("Wait for %d to close", opts.monitor.port);
                    listener_socket_thread.join();
                    //          ping.close;
                    //            listener_socket.close;

                    log("Thread joined %d", opts.monitor.port);
                }
        }

        // try{
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
                    &handleState, (string json) {
                listener_socket.broadcast(json);
            }, (immutable(ubyte)[] hibon_bytes) {
                listener_socket.broadcast(hibon_bytes);
            }, (Document doc) { listener_socket.broadcast(doc); }, &taskfailure // (immutable(TagionException) e) {
                    //     // log.error(e.msg);
                    //     stop=true;
                    //     ownerTid.send(e);
                    //     //throw e;
                    // },
                    // (immutable(Exception) e) {
                    //     // log.fatal(e.msg);
                    //     stop=true;
                    //     ownerTid.send(e);
                    //     //throw e;
                    // },
                    // (immutable(Throwable) t) {
                    //     // log.fatal(t.msg);
                    //     stop=true;
                    //     ownerTid.send(t);
                    //     // throw t;
                    // }
            );
            //        log("Running");
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
