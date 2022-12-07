module tagion.testbench.network.SSLSocketTest;

import std.stdio;
import std.string;
import std.socket : InternetAddress, Socket, SocketException, TcpSocket, getAddress, SocketType, AddressFamily, ProtocolType, SocketShutdown;

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

SSL_CTX* InitServerCTX() {
    SSL_METHOD* method;
    SSL_CTX* ctx;
    method = TLS_server_method(); /* create new server-method instance */
    ctx = SSL_CTX_new(method); /* create new context from method */
    if (ctx == null) {
        ERR_print_errors_fp(cast(stdc_io.FILE*) stdc_io.stderr);
        return null;
    }
    return ctx;
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

// SSL_CTX* InitServerCTX()
// {
//     SSL_METHOD *method;
//     SSL_CTX *ctx;
//     OpenSSL_add_all_algorithms();     /* load & register all cryptos, etc. */
//     SSL_load_error_strings();         /* load all error messages */
//     method = TLSv1_2_server_method(); /* create new server-method instance */
//     ctx = SSL_CTX_new(method);        /* create new context from method */
//     if (ctx == null)
//     {
//         ERR_print_errors_fp(cast(stdc_io.FILE*)stdc_io.stderr);
//         return null;
//     }
//     return ctx;
// }

void LoadCertificates(SSL_CTX* ctx, string CertFile, string KeyFile) {
    /* set the local certificate from CertFile */
    if (SSL_CTX_use_certificate_file(ctx, CertFile.toStringz, SSL_FILETYPE_PEM) <= 0) {
        ERR_print_errors_fp(cast(stdc_io.FILE*) stdc_io.stderr);
        return;
    }
    /* set the private key from KeyFile (may be the same as CertFile) */
    if (SSL_CTX_use_PrivateKey_file(ctx, KeyFile.toStringz, SSL_FILETYPE_PEM) <= 0) {
        ERR_print_errors_fp(cast(stdc_io.FILE*) stdc_io.stderr);
        return;
    }
    /* verify private key */
    if (!SSL_CTX_check_private_key(ctx)) {
        writeln("Private key does not match the public certificate");
        return;
    }
}

Socket OpenListener(string address, ushort port) {

    auto socket = new Socket(AddressFamily.INET, SocketType.STREAM);

    auto addr = getAddress(address, port);
    socket.bind(addr[0]);
    socket.listen(10);

    return socket;
}

bool Servlet(SSL* ssl) /* Serve the connection -- threadable */ {
    auto buffer = new char[1024];
    int bytes;
    const ret = SSL_accept(ssl);
    if (ret == 1) { /* do SSL-protocol accept */
        bytes = SSL_read(ssl, buffer.ptr, cast(int) buffer.length); /* get request */
        buffer.length = bytes;
        if (bytes > 0) {
            SSL_write(ssl, buffer.ptr, bytes); /* send reply */
        }
        else {
            ERR_print_errors_fp(cast(stdc_io.FILE*) stdc_io.stderr);
        }
        writefln("Client msg: %s", buffer[0 .. bytes]);

    }
    else {
        ERR_print_errors_fp(cast(stdc_io.FILE*) stdc_io.stderr);

    }
    SSL_shutdown(ssl);
    // close(sd);            /* close connection */
    SSL_free(ssl); /* release SSL state */
    writefln("buf=%s", buffer);
    return buffer == "EOC";
}

void _SSLSocketServer(string address, const ushort port, string cert) {

    auto ctx = InitServerCTX();
    /* initialize SSL */
    LoadCertificates(ctx, cert, cert); /* load certs */
    auto server = OpenListener(address, port); /* create server socket */

    bool stop;
    server.listen(3);
    while (!stop) {
        SSL* ssl;
        auto client = server.accept(); /* accept connection as usual */
        ssl = SSL_new(ctx); /* get new SSL state with context */
        SSL_set_fd(ssl, client.handle); /* set connection socket to SSL state */
        stop = Servlet(ssl); /* service connection */
    }
    writeln("shutdown!");
    SSL_CTX_free(ctx);
    server.shutdown(SocketShutdown.BOTH);
    server.close();
}

void __SSLSocketServer(string address, const ushort port, string cert) {

    auto ctx = InitServerCTX();
    /* initialize SSL */
    LoadCertificates(ctx, cert, cert); /* load certs */
    auto server = OpenListener(address, port); /* create server socket */

    bool stop;
    server.listen(3);
    while (!stop) {
        SSL* ssl;
        auto client = server.accept(); /* accept connection as usual */
        ssl = SSL_new(ctx); /* get new SSL state with context */
        SSL_set_fd(ssl, client.handle); /* set connection socket to SSL state */
        stop = Servlet(ssl); /* service connection */
    }
    writeln("shutdown!");
    SSL_CTX_free(ctx);
    server.shutdown(SocketShutdown.BOTH);
    server.close();
}
