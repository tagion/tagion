module tagion.services.TransactionService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;
import std.exception : assumeUnique;

import tagion.services.LoggerService;
import tagion.Options : Options, setOptions, options;
import tagion.Base : Control, basename, bitarray2bool, Pubkey;
import tagion.communication.ListenerSocket;
import tagion.TagionExceptions;

//Create flat webserver start class function - create Backend class.
void transactionServiceTask(immutable(Options) opts) {
    // Set thread global options
    setOptions(opts);
    immutable task_name=opts.transaction.task_name;
    writefln("opts.transaction.task_name=%s", opts.transaction.task_name);

    log.register(task_name);

    log("SockectThread port=%d addresss=%s", opts.transaction.port, opts.url);

    scope(success) {
        ownerTid.prioritySend(Control.END);
    }

    auto listener_socket = ListenerSocket(opts, opts.url, opts.transaction.port, opts.transaction.task_name);
    // void delegate() listerner;
    // listerner.funcptr = &ListenerSocket.run;
    // listerner.ptr = &listener_socket;
    auto listener_socket_thread = listener_socket.start;


    scope(exit) {
        log("In exit of soc. port=%d th", opts.transaction.port);
        listener_socket.stop;
        version(none)
        if ( listener_socket_thread !is null ) {
            //  listener_socket.close;
            listener_socket.stop;

            log("Kill listener socket. %d", opts.transaction.port);
            //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.
            auto ping=new TcpSocket(new InternetAddress(opts.url, opts.transaction.port));
            log("run_listerner %s %s", listener_socket.active, opts.transaction.port);

            listener_socket_thread.join();
            ping.close;
            listener_socket.close;
            log("Thread joined %d", opts.transaction.port);
        }
    }

    // try{
    bool stop;
//        bool runBackend = true;
    void handleState (Control ts) {
        with(Control) switch(ts) {
            case STOP:
                log("Kill socket thread. %d", opts.transaction.port);
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
            (immutable(TagionException) e) {
                // stop=true;
                //throw e;
                log.fatal(e.msg);
                ownerTid.send(e);
            },
            (immutable(Exception) e) {
                // stop=true;
                //throw e;
                log.fatal(e.msg);
                ownerTid.send(e);
            },
            (immutable(Throwable) t) {
                    // stop=true;
                log.fatal(t.msg);
                ownerTid.send(t);
                    //throw t;
            }
            );
    }
    // }
    // catch(Exception e) {
    //     log.fatal("Exception %d", opts.transaction.port);
    //     log.fatal(e.toString);
    //     ownerTid.send(cast(immutable)e);
    // }
    // catch(Throwable t) {
    //     log.fatal("Throwable %d", opts.transaction.port);
    //     log.fatal(t.toString);
    //     ownerTid.send(cast(immutable)t);
    // }
}
