module tagion.services.MonitorService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;

import tagion.services.LoggerService;
import tagion.Options : Options, setOptions, options;
import tagion.basic.Basic : Control, basename, bitarray2bool, Pubkey;
import tagion.basic.TagionExceptions : TagionException;

import tagion.hibon.Document;
import tagion.communication.ListenerSocket;
import tagion.basic.TagionExceptions;

//Create flat webserver start class function - create Backend class.
void monitorServiceTask(immutable(Options) opts) {
    // Set thread global options
    setOptions(opts);
    immutable task_name=opts.monitor.task_name;
    log.register(task_name);

    try{
    log("SockectThread port=%d addresss=%s", opts.monitor.port, opts.url);
    // scope(failure) {
    //     log.error("In failure of soc. port=%d th., flag %s:", opts.monitor.port, Control.FAIL);
    //     ownerTid.prioritySend(Control.FAIL);
    // }

    scope(success) {
        log("In success of soc. port=%d th., flag %s:", opts.monitor.port, Control.END);
        ownerTid.prioritySend(Control.END);
    }
    auto listener_socket = ListenerSocket(
        opts,
        opts.url,
        opts.monitor.port,
        opts.monitor.timeout,
        opts.monitor.task_name);
    auto listener_socket_thread=listener_socket.start;

    // void delegate() listerner;
    // listerner.funcptr = &ListenerSocket.run;
    // listerner.ptr = &listener_socket;
    // auto listener_socket_thread = new Thread( listerner ).start();

//    version(none)
    scope(exit) {
        log("In exit of soc. port=%d th", opts.monitor.port);
        listener_socket.stop;

        version(none)
        if ( listener_socket_thread !is null ) {
            //  listener_socket.close;
            listener_socket.stop;

            log("Kill listener socket. %d", opts.monitor.port);
            //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.
//            if ( ldo.active ) {
            auto ping=new TcpSocket(new InternetAddress(opts.url, opts.monitor.port));
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
//        bool runBackend = true;
    void handleState (Control ts) {
        with(Control) switch(ts) {
            case STOP:
                log("Kill socket thread. %d", opts.monitor.port);
                // if ( listener_socket_thread !is null ) {
                //     listener_socket.stop;
                //     writefln("Wait for %d to close", opts.monitor.port);
                //     listener_socket_thread.join();
                //     log("Thread joined %d", opts.monitor.port);
                // }

                stop = true;
                break;
                // case LIVE:
                //     stop = false;
                //     break;
            default:
                log.error("Bad Control command %s", ts);
                //    stop=true;
            }
    }

    ownerTid.send(Control.LIVE);
    while(!stop) {
        receiveTimeout(500.msecs,
            //Control the thread
            &handleState,
            (immutable(ubyte)[] hibon_bytes) {
                listener_socket.broadcast(hibon_bytes);
            },
            (Document doc) {
                listener_socket.broadcast(doc);
            },
            (immutable(TagionException) e) {
                log.error(e.msg);
                stop=true;
                ownerTid.send(e);
                //throw e;
            },
            (immutable(Exception) e) {
                log.fatal(e.msg);
                stop=true;
                ownerTid.send(e);
                //throw e;
            },
            (immutable(Throwable) t) {
                log.fatal(t.msg);
                stop=true;
                ownerTid.send(t);
                // throw t;
            }
            );
//        log("Running");
    }
//     }
//     catch(TagionException e) {
//         log.error("TagionException %d", opts.monitor.port);
// //        log.error(e.toString);
//         ownerTid.send(cast(immutable)e);
//     }
//     catch(Exception e) {
//         log.fatal("Exception %d", opts.monitor.port);
// //        log.fatal(e.toString);
//         ownerTid.send(cast(immutable)e);
//     }
//     catch(Throwable t) {
//         log.fatal("Throwable %d", opts.monitor.port);
// //        log.fatal(t.toString);
//         ownerTid.send(cast(immutable)t);
//     }
    }catch(Exception e){
        log.fatal(e.msg);
        throw e;
    }
}
