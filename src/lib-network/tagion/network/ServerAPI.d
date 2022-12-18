module tagion.network.ServerAPI;

import core.time : dur, Duration;
import core.thread;
import std.stdio : writeln, writefln, stdout;
import std.socket : InternetAddress, Socket, SocketSet, SocketShutdown, shutdown, AddressFamily;
import std.concurrency;
import std.format;

import tagion.network.SSLSocket;
import tagion.network.FiberServer;
import tagion.network.SSLServiceOptions;
import tagion.network.SSLSocketException;
import tagion.GlobalSignals : abort;

import tagion.logger.Logger;
import tagion.basic.Types : Control;
import tagion.basic.TagionExceptions : fatal;

import io = std.stdio;

@safe
struct ServerAPI {
    immutable(ServerOptions) opts;
    protected {
        Thread service_task;
        FiberServer service;
        FiberServer.Relay relay;
        Socket listener;
    }

    @disable this();

    this(immutable(ServerOptions) opts,
            Socket listener,
            FiberServer.Relay relay) nothrow pure @trusted {
        this.opts = opts;
        this.listener = listener;
        this.relay = relay;
    }

    protected shared(bool) stop_service;

    @trusted
    static void sleep(Duration time) {
        Thread.sleep(time);
    }

    void stop() @trusted {
        if (service_task !is null) {
            stop_service = true;
			service_task.join;
            service_task = null;
        }
    }

    void send(uint id, immutable(ubyte[]) buffer) {
        service.send(id, buffer);
    }

    @trusted
    void run() nothrow {
        try {
            io.writefln("Started %d", opts.max_queue_length);
            log.register(opts.server_task_name);
            check(listener.isAlive,
                    format("Listener is dead for response task %s", opts.server_task_name));
            listener.blocking = false;
            listener.bind(new InternetAddress(opts.address, opts.port));
            listener.listen(opts.max_queue_length);

            service = new FiberServer(opts, listener, relay);
            service.start;
            scope (exit) {
                service.stop;
            }
            auto socket_set = new SocketSet(opts.max_queue_length + 1);
            scope (exit) {
                socket_set.reset;
                service.closeAll;
                listener.shutdown(SocketShutdown.BOTH);
            }

            while (!stop_service && !abort) {
                io.writefln("Wait loop");
                if (!listener.isAlive) {
                    stop_service = true;
                    break;
                }

                socket_set.add(listener);

                service.addSocketSet(socket_set);

                const sel_res = Socket.select(
                        socket_set, null, null,
                        opts.select_timeout.msecs);
                if (sel_res > 0) {

                    if (socket_set.isSet(listener)) {
                        service.allocateFiber;
                    }
                }
                assert(service !is null, "This should not be possible");
			io.writefln("Before execute %s abort %s ", stop_service, abort);	
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
        check(service_task is null, "Server task has already been started");
        stop_service = false;
        service_task = new Thread(&run).start;
        return service_task;
    }

}
