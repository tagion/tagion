module tagion.network.SSLServiceAPI;

import core.time : dur, Duration;
import core.thread;
import std.stdio : writeln, writefln, stdout;
import std.socket : InternetAddress, Socket, SocketSet, SocketShutdown, shutdown, AddressFamily;
import std.concurrency;
import std.format;

import tagion.network.SSLSocket;
import tagion.network.SSLFiberService;
import tagion.network.SSLOptions;
import tagion.network.SSLSocketException;

import tagion.logger.Logger;
import tagion.basic.Types : Control;
import tagion.basic.TagionExceptions : fatal;

@safe
struct SSLServiceAPI {
    immutable(SSLOptions) ssl_options;
    immutable(ServiceOptions) opts;
    protected {
        Thread service_task;
        SSLFiberService service;
        SSLFiberService.Relay relay;
    }
    //    const(HiRPC) hirpc;

    @disable this();

    this(immutable(SSLOptions) opts, SSLFiberService.Relay relay) nothrow pure @trusted {
        this.ssl_options = opts;
        this.opts = ssl_options.socket;
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
            log("Run SSLServiceAPI. Certificate=%s, ssl_options.private_key=%s",
                    ssl_options.ssl.certificate,
                    ssl_options.ssl.private_key);
            auto _listener = new SSLSocket(
                    AddressFamily.INET,
                    SocketType.STREAM,
                    ssl_options.ssl.certificate,
                    ssl_options.ssl.private_key);
            assert(_listener.isAlive);
            _listener.blocking = false;
            _listener.bind(new InternetAddress(opts.address, opts.port));
            _listener.listen(opts.max_queue_length);

            service = new SSLFiberService(opts, _listener, relay);
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
                _listener.shutdown(SocketShutdown.BOTH);
                _listener = null;
            }

            while (!stop_service) {
                if (!_listener.isAlive) {
                    stop_service = true;
                    break;
                }

                socket_set.add(_listener);

                service.addSocketSet(socket_set);

                const sel_res = Socket.select(socket_set, null, null,
                        opts.select_timeout.msecs);
                if (sel_res > 0) {
                    if (socket_set.isSet(_listener)) {
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
