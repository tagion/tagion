module tagion.testbench.network.SSLSocketTest;


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
	
	return buffer[0..size].idup;
}
