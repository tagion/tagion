module tagion.network.ServerAPI;

import core.time : dur, Duration;
import core.thread;
import std.stdio : writeln, writefln, stdout;
import std.socket : InternetAddress, Socket, SocketSet, SocketShutdown, shutdown, AddressFamily;
import std.concurrency;
import std.format;

import tagion.network.SSLSocket;
import tagion.network.ServerFiber;
import tagion.network.SSLServiceOptions;
import tagion.network.SSLSocketException;

import tagion.logger.Logger;
import tagion.basic.Types : Control;
import tagion.basic.TagionExceptions : fatal;

@safe
struct ServerAPI {
    immutable(ServerOptions) opts;
    protected {
        Thread service_task;
        ServerFiber service;
        ServerFiber.Relay relay;
        Socket listener;
    }
    //    const(HiRPC) hirpc;

    @disable this();

    this(immutable(ServerOptions) opts, Socket listener, ServerFiber.Relay relay) nothrow pure @trusted {
        this.opts = opts;
        this.listener = listener;
        this.relay = relay;
    }

    protected shared(bool) stop_service;

    @trusted
    static void sleep(Duration time) {
        Thread.sleep(time);
    }

    void stop() nothrow {
        stop_service = true;
    }

    void send(uint id, immutable(ubyte[]) buffer) {
        service.send(id, buffer);
    }

    @trusted
    void run() nothrow {
        try {
            import std.socket : SocketType;

            log.register(opts.task_name);
            assert(listener.isAlive);
            listener.blocking = false;
            listener.bind(new InternetAddress(opts.address, opts.port));
            listener.listen(opts.max_queue_length);

            service = new ServerFiber(opts, listener, relay);
            auto response_tid = service.start(opts.response_task_name);
            if (response_tid !is Tid.init) {

                check(receiveOnly!Control is Control.LIVE,
                        format("SSL service task %s is not alive",
                        opts.response_task_name));
            }
            scope (exit) {
                response_tid.send(Control.STOP);
                const ctrl = receiveOnly!Control;
                if (ctrl !is Control.END) {
                    log.warning("Unexpected control %s code", ctrl);
                }
            }
            auto socket_set = new SocketSet(opts.max_connections + 1);
            scope (exit) {
                socket_set.reset;
                service.closeAll;
                listener.shutdown(SocketShutdown.BOTH);
                listener = null;
            }

            while (!stop_service) {
                if (!listener.isAlive) {
                    stop_service = true;
                    break;
                }

                socket_set.add(listener);

                service.addSocketSet(socket_set);

                const sel_res = Socket.select(socket_set, null, null,
                        opts.select_timeout.msecs);
                if (sel_res > 0) {
                    if (socket_set.isSet(listener)) {
                        service.allocateFiber;
                    }
                }
                service.execute(socket_set);
                socket_set.reset;
            }
        }
        catch (Throwable e) {
            fatal(e);
        }
    }

    @trusted
    Thread start() {
        service_task = new Thread(&run).start;
        return service_task;
    }

}
