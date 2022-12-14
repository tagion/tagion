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
        check(response == message,
                format("Error: message and response not the same got: <%s>", response));
    }
    writefln("##### DONE %s\n", prefix);
    if (send_to_owner) {
        ownerTid.send(true);
    }
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
