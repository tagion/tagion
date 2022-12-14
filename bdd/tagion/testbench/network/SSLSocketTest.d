module tagion.testbench.network.SSLSocketTest;

import std.stdio;
import std.string;
import std.socket : InternetAddress, Socket, SocketException, TcpSocket, getAddress, SocketType, AddressFamily, ProtocolType, SocketShutdown, SocketSet;

import tagion.network.SSLSocket;
import stdc_io = core.stdc.stdio;
import tagion.network.SSL;
import std.concurrency;
import tagion.behaviour;
import core.thread;

version (WOLFSSL) {
    void ERR_print_errors_fp(stdc_io.FILE* fp) {
        writefln("WolfSSL error");
    }
}
//import tagion.network.
SSL_CTX* InitCTX() {
    //SSL_METHOD* method;
    SSL_CTX* ctx;
    //    OpenSSL_add_all_algorithms();     /* Load cryptos, et.al. */
    //    SSL_load_error_strings();         /* Bring in and register error messages */
    //method = TLS_client_method(); /* Create new client-method instance */
    ctx = SSL_CTX_new(TLS_client_method); /* Create new context */
    if (ctx == null) {
        ERR_print_errors_fp(cast(stdc_io.FILE*) stdc_io.stderr);
        return null; //abort();
    }
    return ctx;
}

SSL_CTX* InitServerCTX() {
    //    SSL_METHOD* method;
    SSL_CTX* ctx;
    //    method = TLS_server_method(); /* create new server-method instance */
    ctx = SSL_CTX_new(TLS_server_method()); /* create new context from method */
    if (ctx == null) {
        ERR_print_errors_fp(cast(stdc_io.FILE*) stdc_io.stderr);
        return null;
    }
    return ctx;
}

//@safe
version(none)
@trusted
string _echoSSLSocket(string address, const ushort port, string msg) {
    import std.conv : to;

    auto addresses = getAddress(address, port);
    auto buffer = new char[1024];
    size_t size;
    auto socket = new SSLSocket(AddressFamily.INET, SocketType.STREAM); //, ProtocolType.TCP);
    socket.connect(addresses[0]);
    socket.send(msg);
    Thread.sleep(10.msecs);
    size = socket.receive(buffer);
    writefln("size=%d", size);
    buffer[size] = 0;
    socket.shutdown;
    socket.close;
    return buffer[0 .. size].idup;
}

version(none)
@trusted
string __echoSSLSocket(string address, const ushort port, string msg) {
    import std.conv : to;

    auto addresses = getAddress(address, port);
    auto buffer = new char[1024];
    size_t size;
    auto socket = new Socket(AddressFamily.INET, SocketType.STREAM); //, ProtocolType.TCP);
    socket.connect(addresses[0]);
    socket.send(msg);
    Thread.sleep(10.msecs);
    size = socket.receive(buffer);
    writefln("size=%d", size);
    buffer[size] = 0;
    socket.shutdown(SocketShutdown.BOTH);
    socket.close;
    return buffer[0 .. size].idup;
}

//alias echoSSLSocket = echoWolfSSLSocket;

version(WOLFSSL) {
import tagion.network.wolfssl.c.ssl : WOLFSSL_CTX;

__gshared WOLFSSL_CTX* client_ctx;

shared static this() {
    import tagion.network.wolfssl.c.ssl;

    WOLFSSL_METHOD* method;
    method = wolfTLS_client_method(); /* use TLS v1.2 */

    /* make new ssl context */

    if ((client_ctx = wolfSSL_CTX_new(method)) is null) {
        writefln("wolfSSL CTX error");
        //err_sys("wolfSSL_CTX_new error");
    }
}

shared static ~this() {
    import tagion.network.wolfssl.c.ssl;

    wolfSSL_CTX_free(client_ctx);
}
}
@trusted
string echoSSLSocket(string address, const ushort port, string msg) {
	version(WOLFSSL)   import tagion.network.wolfssl.c.ssl;

    auto buffer = new char[1024];
    auto socket = new SSLSocket(AddressFamily.INET, SocketType.STREAM); //, ProtocolType.TCP);
    auto addresses = getAddress(address, port);
    socket.connect(addresses[0]);
	writef("*");
    socket.send(msg);
    const size = socket.receive(buffer);
    socket.shutdown;
    return buffer[0 .. size].idup;
}

version(none) 
@trusted
string echoWolfSSLSocket(string address, const ushort port, string msg) {
    import tagion.network.wolfssl.c.ssl;

    auto buffer = new char[1024];
    size_t size;
    int sockfd;

    //    WOLFSSL_CTX* ctx;

    WOLFSSL* ssl;

    writefln("wolfSSLSocket %s", msg);
    // const char message[] = "Hello, World!";

    /* create and set up socket */

    auto socket = new Socket(AddressFamily.INET, SocketType.STREAM); //, ProtocolType.TCP);
    //auto socket = new Socket()
    sockfd = socket.handle;

    /* initialize wolfssl library */

    //    wolfSSL_Init();

    /* make new wolfSSL struct */

    if ((ssl = wolfSSL_new(client_ctx)) is null) {

        writeln("wolfSSL_new error");
        return null;
    }

    auto addresses = getAddress(address, port);
    socket.connect(addresses[0]);

    /* Add cert to ctx */
    version (none)
        if (wolfSSL_CTX_load_verify_locations(ctx, "certs/ca-cert.pem", 0) !=

                SSL_SUCCESS) {

            err_sys("Error loading certs/ca-cert.pem");

        }

    /* Connect wolfssl to the socket, server, then send message */

    wolfSSL_set_fd(ssl, sockfd);

    wolfSSL_connect(ssl);

    wolfSSL_write(ssl, msg.ptr, cast(int) msg.length); //strlen(message));

    size = wolfSSL_read(ssl, buffer.ptr, cast(int) buffer.length);
    //    size = socket.receive(buffer);
    // writefln("size=%d", size);

    const ret = wolfSSL_shutdown(ssl);
    if (ret != 0) {
        writefln("Shutdown failed");
        return null;
    }
    //assert(ret == 0);
    /* frees all data before client termination */

    wolfSSL_free(ssl);

    return buffer[0 .. size].idup;

    //  wolfSSL_Cleanup();
}

@trusted
void echoSSLSocketTask(
        string address,
        immutable ushort port,
        string prefix,
        immutable uint calls,

        immutable bool send_to_owner) {
    foreach (i; 0 .. calls) {
        const message = format("%s%s", prefix, i);
        const response = echoSSLSocket(address, port, message);
        //const response = echoWolfSSLSocket(address, port, message);
        //    writefln("response: <%s>", response);
        check(response == message,
                format("Error: message and response not the same got: <%s>", response));
    }
    writefln("##### DONE %s\n", prefix);
    if (send_to_owner) {
        ownerTid.send(true);
    }
}

import tagion.network.SSLServiceOptions;

version (none) void SSLSocketServer(immutable(SSLServiceOptions) ssl_options) {
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

version(none)
void __SSLSocketServer(string address, const ushort port, string cert) {

    auto ctx = InitServerCTX();
    /* initialize SSL */
    LoadCertificates(ctx, cert, cert); /* load certs */
    auto server = OpenListener(address, port); /* create server socket */
    // server.blocking(false);
    // auto readSet = new SocketSet;
    // auto writeSet = new SocketSet;

    // Socket[] sockets;

    server.listen(3);
    bool stop;
    while (!stop) {
        // readSet.reset();
        // writeSet.reset();

        // // add sockets if they are alive.
        // foreach(ref socket; sockets) {
        //     if(socket.isAlive) {
        //         readSet.add(socket);
        //     }
        // }

        // auto eventCount = Socket.select(readSet, writeSet, null); //, 5.seconds);

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

version(none)
void x_SSLSocketServer(string address, const ushort port, string cert) {

    //    auto ctx = InitServerCTX();
    /* initialize SSL */
    //    LoadCertificates(ctx, cert, cert); /* load certs */
    //    auto server = OpenListener(address, port); /* create server socket */
    auto server = new SSLSocket(AddressFamily.INET, SocketType.STREAM, cert);
    auto addr = getAddress(address, port);
    server.bind(addr[0]);
    server.listen(10);

    bool stop;
    //    server.listen(3);
    while (!stop) {
        SSL* ssl;
        auto client = server.accept(); /* accept connection as usual */
        ssl = SSL_new(server.ctx); /* get new SSL state with context */
        SSL_set_fd(ssl, client.handle); /* set connection socket to SSL state */
        stop = Servlet(ssl); /* service connection */
    }
    writeln("shutdown!");
    //    SSL_CTX_free(ctx);
    server.shutdown(SocketShutdown.BOTH);
    server.close();
}

@trusted
void echoSSLSocketServer(string address, const ushort port, string cert) {
    auto server = new SSLSocket(AddressFamily.INET, SocketType.STREAM, cert);
    auto addr = getAddress(address, port);
    auto buffer = new char[1024];
    server.bind(addr[0]);
    server.listen(10);

    bool stop;
    while (!stop) {
        auto client = cast(SSLSocket) server.accept(); /* accept connection as usual */
        const size = client.receive(buffer);
        const received_buffer = buffer[0 .. size];
        SSL_write(client.ssl, buffer.ptr, cast(int)size); /* send reply */
        client.send(received_buffer);
        client.shutdown;
        stop = received_buffer == "EOC"; /* service connection */
    }
    writeln("shutdown!");
    server.shutdown(SocketShutdown.BOTH);
    server.close();
}
