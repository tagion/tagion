module tagion.network.SSLServiceAPI;

import core.time : dur, Duration;
import core.thread;
import std.stdio : writeln, writefln, stdout;
import std.socket : InternetAddress, Socket, SocketSet, SocketShutdown, shutdown, AddressFamily;
import std.concurrency;

import tagion.Options;
import tagion.network.SSLSocket;
import tagion.network.SSLFiberService;
import tagion.services.LoggerService;
import tagion.basic.Basic : Control;


@safe
struct SSLServiceAPI {
    immutable(Options.SSLService) ssl_options;
    protected {
        Thread service_task;
        SSLFiberService.Relay relay;
    }
//    const(HiRPC) hirpc;

    @disable this();

    this(immutable(Options.SSLService) opts, SSLFiberService.Relay relay) @trusted {
        this.ssl_options=opts;
        this.relay=relay;
    }

    protected shared(bool) stop_service;

    @trusted
    static final void sleep(Duration time) {
        Thread.sleep(time);
    }

    final void stop() {
        stop_service = true;
    }

    // SSLFiberService fiberService(immutable(Options.SSLService) opts, SSLSocket listener, const HiRPC hirpc) {
    //     return new SSLFiberService(opts, listener, hirpc);
    // }


    @system
    void run() {
        log.register(ssl_options.task_name);
        auto _listener = new SSLSocket(AddressFamily.INET, EndpointType.Server);
        assert(_listener.isAlive);
        log("certificate=%s, ssl_options.private_key=%s", ssl_options.certificate, ssl_options.private_key);
        _listener.configureContext(ssl_options.certificate, ssl_options.private_key);
        //_listener.configureContext(ssl_options.certificate, ssl_options.private_key);
        _listener.blocking = false;
        _listener.bind(new InternetAddress( ssl_options.address, ssl_options.port ));
        _listener.listen(ssl_options.max_queue_length);

        auto service = new SSLFiberService(ssl_options, _listener, relay);
        auto response_tid = service.start(ssl_options.response_task_name);
        if (response_tid != Tid.init) {
            if (receiveOnly!Control !is Control.LIVE) {
                ownerTid.send(Control.FAIL);
            }
        }
        scope(exit) {
            response_tid.send(Control.STOP);
            if (receiveOnly!Control !is Control.END) {
                ownerTid.send(Control.FAIL);
            }
        }
        auto socket_set = new SocketSet(ssl_options.max_connections+1);
        scope (exit) {
            socket_set.reset;
            service.closeAll;
            _listener.shutdown(SocketShutdown.BOTH);
            _listener=null;
        }

        while (!stop_service) {
            if ( !_listener.isAlive ){
                stop_service = true;
                break;
            }

            socket_set.add(_listener);

            service.addSocketSet(socket_set);

            const sel_res = Socket.select( socket_set, null, null, ssl_options.select_timeout.msecs);
            if (sel_res > 0) {
                if (socket_set.isSet(_listener)) {
                    service.allocateFiber;
                }
            }
            service.execute(socket_set);
            socket_set.reset;
        }
    }

    @system
    final Thread start() {
        service_task=new Thread(&run).start;
        return service_task;
    }

}
