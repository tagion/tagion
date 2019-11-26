module tagion.services.TransactionService;

import std.stdio : writeln, writefln;
import std.format;
import std.socket;
import core.thread;
import std.concurrency;

import tagion.services.LoggerService;
import tagion.Options : Options, setOptions, options;
import tagion.Base : Control, basename, bitarray2bool, Pubkey;
import tagion.communication.ListenerSocket;


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

    auto listener_socket = ListenerSocket(opts, opts.url, opts.transaction.port);
    void delegate() listerner;
    listerner.funcptr = &ListenerSocket.run;
    listerner.ptr = &listener_socket;
    auto listener_socket_thread = new Thread( listerner ).start();

    scope(exit) {
        log("In exit of soc. port=%d th", opts.monitor.port);

        if ( listener_socket_thread !is null ) {
            listener_socket.stop;
            listener_socket.close;
            log("Kill listener socket. %d", opts.monitor.port);
            //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.
            auto ping=new TcpSocket(new InternetAddress(opts.url, opts.monitor.port));
            log("run_listerner %s %s", listener_socket.active, opts.monitor.port);

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
                (immutable(ubyte)[] hibon_bytes) {
                    listener_socket.broadcast(hibon_bytes);
                },
                (immutable(Exception) e) {
                    stop=true;
                    ownerTid.send(e);
                },
                (immutable(Throwable) t) {
                    stop=true;
                    ownerTid.send(t);
                    throw t;

                }
                );
        }
    }
    catch(Throwable t) {
        log.fatal("Throwable %d", opts.monitor.port);
        ownerTid.send(cast(immutable)t);
    }
}
