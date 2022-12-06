module tagion.testbench.network.SSLSocketTest;

import std.stdio;

import std.socket : InternetAddress, Socket, SocketException, TcpSocket, getAddress, SocketType, AddressFamily, ProtocolType;

import tagion.network.SSLSocket;
import stdc_io = core.stdc.stdio;
import tagion.network.SSL;

//import tagion.network.
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

//@safe
@trusted
string echoSSLSocket(string address, const ushort port, string msg) {
    //    auto socket = new SSLSocket(AddressFamily.INET, EndpointType.Client, SocketType.STREAM); //, ProtocolType.TCP);
    import std.conv : to;

    //    auto ctx = InitCTX();
    auto addresses = getAddress(address, port);
    writefln("Address=%s", addresses);

    auto buffer = new char[1024];
    /*
	socket.send(msg);
    const size = socket.receive(buffer);
*/
    //	import std.socket;

    size_t size;
    auto socket = new SSLSocket(AddressFamily.INET, SocketType.STREAM); //, ProtocolType.TCP);
    //auto socket = new Socket();
    socket.connect(addresses[0]);
    //	auto ssl = SSL_new(socket.ctx);
    //	socket.send(msg);
    //    const size = socket.receive(buffer);
    writefln("%s:%d", buffer.to!string, size);
    //	socket.close;
    //    ssl = SSL_new(socket.ctx);           /* create new SSL connection state */
    /+
	SSL_set_fd(socket.ssl, socket.handle);      /* attach the socket descriptor */
    if (SSL_connect(socket.ssl) == -1) { /* perform the connection */
	    writefln("Error SSL_connect");
		ERR_print_errors_fp(cast(stdc_io.FILE*)stdc_io.stderr);
	}
    else
    {
		+/
    // char stdin_buffer[BUFFER_SIZE] = {0};

    // scanf("%s", stdin_buffer);
    // printf("\n\nConnected with %s encryption\n", SSL_get_cipher(ssl));
    // ShowCerts(ssl);        /* get any certs */
    socket.send(msg);
    //   SSL_write(socket.ssl, msg.ptr, cast(int)msg.length); /* encrypt & send message */
    //        size = SSL_read(socket.ssl, buffer.ptr, cast(int)buffer.length);            /* get reply & decrypt */

    size = socket.receive(buffer);
    buffer[size] = 0;
    writefln("size=%d", size);
    writefln("%s", buffer);
    // }
    SSL_shutdown(socket.ssl);
    //close(server); /* close socket */
    //    SSL_free(ssl);
    //    SSL_CTX_free(socket.ctx);
    socket.close;
    //	size_t size;
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
