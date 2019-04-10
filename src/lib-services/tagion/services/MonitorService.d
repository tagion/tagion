module tagion.services.MonitorService;

import std.stdio : writeln, writefln;
import std.socket;
import core.thread;
import std.concurrency;

import tagion.Options : Options;
import tagion.Base : Control, basename, bitarray2bool, Pubkey;
import tagion.communication.ListenerSocket;


//Create flat webserver start class function - create Backend class.
void monitorServiceThread(string url, immutable ushort port) {
    Options opts;
    opts.monitor.port=port;
    opts.url=url;

    writefln("SockectThread port=%d addresss=%s", opts.monitor.port, opts.url);
    scope(failure) {
        writefln("In failure of soc. port=%d th., flag %s:", opts.monitor.port, Control.FAIL);
        ownerTid.prioritySend(Control.FAIL);
    }

    scope(success) {
        writefln("In success of soc. port=%d th., flag %s:", opts.monitor.port, Control.END);
        ownerTid.prioritySend(Control.END);
    }

//    auto lso = ListenerSocket(opts.monitor.port, opts.url, thisTid);
    auto lso = ListenerSocket(thisTid, opts.url, opts.monitor.port);
    void delegate() ls;
    ls.funcptr = &ListenerSocket.run;
    ls.ptr = &lso;
    auto listener_socket_thread = new Thread( ls ).start();

    scope(exit) {
        writefln("In exit of soc. port=%d th", opts.monitor.port);

        if ( listener_socket_thread !is null ) {
            lso.close;
            writefln("Kill listener socket. %d", opts.monitor.port);
            //BUG: Needs to ping the socket to wake-up the timeout again for making the loop run to exit.
//            if ( ldo.active ) {
            auto ping=new TcpSocket(new InternetAddress(opts.url, opts.monitor.port));
//                receive( &handleClient);
//                Thread.sleep(500.msecs);
            // run_listener = false;
            writefln("run_listerner %s %s", lso.active, opts.monitor.port);
//            }
            lso.stop;
            listener_socket_thread.join();
            ping.close;
            writefln("Thread joined %d", opts.monitor.port);
        }

    }

    try{

        bool runBackend = true;
        void handleState (Control ts) {
            with(Control) switch(ts) {
                case STOP:
                    writefln("Kill socket thread. %d", opts.monitor.port);
                    runBackend = false;
                    break;
                case LIVE:
                    runBackend = true;
                    break;
                default:
                    writefln("Bad Control command %s", ts);
                    runBackend = false;
                }
        }

        while(runBackend) {
            receiveTimeout(500.msecs,
                //Control the thread
                &handleState,

                // &handleClient,

                // (string msg) {
                //     writeln("The backend socket thread received the message and sends to client socket: " , msg);
                //     if ( lso.active ) {
                //         lso.sendBytes(generateHoleThroughBsonMsg(msg));
                //     }
                // },

                (immutable(ubyte)[] bson_bytes) {
                    lso.sendBytes(bson_bytes);
                },
                (immutable(Throwable) t) {
                    writefln("Throwable -------------------- %d", opts.monitor.port);
                    writeln(t);
                    runBackend=false;
                }
                );
        }
    }
    catch(Throwable t) {
        writefln(":::::::::: Throwable %d", opts.monitor.port);
        writeln(t);
    }
}
