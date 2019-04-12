module tagion.services.MonitorService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;

import tagion.services.LoggerService;
import tagion.Options : Options, setOptions, options;
import tagion.Base : Control, basename, bitarray2bool, Pubkey, TagionException;
import tagion.utils.BSON : Document;
import tagion.communication.ListenerSocket;


//Create flat webserver start class function - create Backend class.
void monitorServiceTask(immutable(Options) opts) {
    // Set thread global options
    setOptions(opts);
    immutable task_name=opts.monitor.task_name;
    // writefln("Before monitorServiceTask task_name=%s opt.logger=%s options.logger=%s",
    //     task_name,
    //     opts.logger.task_name,
    //     options.logger.task_name,
    //     );
    // // Fixme CBR:
    // // Some race between the logger and this task
    // // This delay hackes it for now
    // Thread.sleep(500.msecs);
    // writefln("After monitorServiceTask task_name=%s opt.logger=%s options.logger=%s",
    //     task_name,
    //     opts.logger.task_name,
    //     options.logger.task_name,
    //     );
    log.register(task_name);

    log("SockectThread port=%d addresss=%s", opts.monitor.port, opts.url);
    scope(failure) {
        log.error("In failure of soc. port=%d th., flag %s:", opts.monitor.port, Control.FAIL);
        ownerTid.prioritySend(Control.FAIL);
    }

    scope(success) {
        log("In success of soc. port=%d th., flag %s:", opts.monitor.port, Control.END);
        ownerTid.prioritySend(Control.END);
    }

    auto listener_socket = ListenerSocket(opts, opts.url, opts.monitor.port);
    void delegate() listerner;
    listerner.funcptr = &ListenerSocket.run;
    listerner.ptr = &listener_socket;
    auto listener_socket_thread = new Thread( listerner ).start();

    scope(exit) {
        log("In exit of soc. port=%d th", opts.monitor.port);

        if ( listener_socket_thread !is null ) {
            listener_socket.close;
            log("Kill listener socket. %d", opts.monitor.port);
            //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.
//            if ( ldo.active ) {
            auto ping=new TcpSocket(new InternetAddress(opts.url, opts.monitor.port));
//                receive( &handleClient);
//                Thread.sleep(500.msecs);
            // run_listener = false;
            log("run_listerner %s %s", listener_socket.active, opts.monitor.port);
//            }
            listener_socket.stop;
            listener_socket_thread.join();
            ping.close;
            log("Thread joined %d", opts.monitor.port);
        }
    }

    try{
        bool stop;
//        bool runBackend = true;
        void handleState (Control ts) {
            with(Control) switch(ts) {
                case STOP:
                    log("Kill socket thread. %d", opts.monitor.port);
                    stop = true;
                    break;
                case LIVE:
                    stop = false;
                    break;
                default:
                    log.error("Bad Control command %s", ts);
                    stop=true;
                }
        }

        while(!stop) {
            receiveTimeout(500.msecs,
                //Control the thread
                &handleState,
                (immutable(ubyte)[] bson_bytes) {
                    listener_socket.broadcast(bson_bytes);
                },
                (Document doc) {
                    listener_socket.broadcast(doc);
                },
                (immutable(TagionException) e) {
                    log.error(e.msg);
                    stop=true;
                    ownerTid.send(e);
                },
                (immutable(Exception) e) {
                    log.error(e.msg);
                    stop=true;
                    ownerTid.send(e);
                },
                (immutable(Throwable) t) {
                    log.fatal(t.msg);
                    stop=true;
                    ownerTid.send(t);
                }
                );
        }
    }
    catch(Throwable t) {
        log.fatal("Throwable %d", opts.monitor.port);
        ownerTid.send(cast(immutable)t);
    }
}
