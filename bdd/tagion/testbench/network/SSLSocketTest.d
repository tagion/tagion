module tagion.testbench.network.SSLSocketTest;

import std.stdio;

import std.socket : InternetAddress, Socket, SocketException, TcpSocket, getAddress, SocketType, AddressFamily, ProtocolType;

import tagion.network.SSLSocket;
import stdc_io = core.stdc.stdio;
import tagion.network.SSL;

//import tagion.network.
version(WOLFSSL) {
}
else {
SSL_CTX* InitCTX() {
    SSL_METHOD* method;
    SSL_CTX* ctx;
    //    OpenSSL_add_all_algorithms();     /* Load cryptos, et.al. */
    //    SSL_load_error_strings();         /* Bring in and register error messages */
    method = TLS_client_method(); /* Create new client-method instance */
    ctx = SSL_CTX_new(method); /* Create new context */
    if (ctx == null) {
        ERR_print_errors_fp(cast(stdc_io.FILE*) stdc_io.stderr);
        return null; //abort();
    }
    return ctx;
}
}

//@safe
@trusted
string echoSSLSocket(string address, const ushort port, string msg) {
    import std.conv : to;
    auto addresses = getAddress(address, port);
    auto buffer = new char[1024];
    size_t size;
    auto socket = new SSLSocket(AddressFamily.INET, SocketType.STREAM); //, ProtocolType.TCP);
    socket.connect(addresses[0]);
    socket.send(msg);
    size = socket.receive(buffer);
    buffer[size] = 0;
	socket.shutdown;
    return buffer[0 .. size].idup;
}

import tagion.network.SSLOptions;

version (none) void SSLSocketServer(immutable(SSLOptions) ssl_options) {
    auto listener = new SSLSocket(AddressFamily.INET, EndpointType.Server);
    assert(listener.isAlive);
    writefln("Run SSLServiceAPI. Certificate=%s, ssl_options.private_key=%s",
            ssl_options.openssl.certificate,
            ssl_options.openssl.private_key);
    listener.configureContext(
            ssl_options.openssl.certificate,
            ssl_options.openssl.private_key);
    listener.blocking = true;
    listener.bind(new InternetAddress(ssl_options.address, ssl_options.port));
    listener.listen(ssl_options.max_queue_length);

    auto socket_set = new SocketSet(ssl_options.max_connections + 0);
    scope (exit) {
        socket_set.reset;
        //                service.closeAll;
        listener.shutdown(SocketShutdown.BOTH);
        listener = null;
    }
    bool stop;
    while (!stop) {
        listener.accept();
        listener.receive(request);
        listener.send(data);
        listener.close();
    }
    version (none)
        while (!stop) {
            if (!listener.isAlive) {
                stop = true;
                break;
            }

            socket_set.add(listener);

            service.addSocketSet(socket_set);

            const sel_res = Socket.select(socket_set, null, null, ssl_options
                    .select_timeout.msecs);
            if (sel_res > 0) {
                if (socket_set.isSet(listener)) {
                    service.allocateFiber;
                }
            }
            service.execute(socket_set);
            socket_set.reset;
        }

}
