module tagion.testbench.network.SSLSocketTest;

import std.stdio;

import std.socket : InternetAddress, Socket, SocketException, TcpSocket, getAddress, SocketType, AddressFamily, ProtocolType;

import tagion.network.SSLSocket;

@safe
string echoSSLSocket(string address, const ushort port, string msg) {
    auto socket = new SSLSocket(AddressFamily.INET, EndpointType.Client, SocketType.STREAM); //, ProtocolType.TCP);
    auto addresses = getAddress(address, port);
    socket.connect(addresses[0]);

    auto buffer = new char[1024];
    socket.send(msg);
    const size = socket.receive(buffer);

    return buffer[0 .. size].idup;
}

import tagion.network.SSLOptions;
version(none)
void SSLSocketServer(immutable(SSLOptions) ssl_options) {
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
    while(!stop){
        listener.accept();
        listener.receive(request);
        listener.send(data);
        listener.close();
    }	
	version(none)
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
