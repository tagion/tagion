module tagion.backend.Backend;

import vibe.core.core : sleep;
import vibe.core.log;
import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.http.websockets : WebSocket, handleWebSockets;
import vibe.data.json;

import core.time;
import std.concurrency;
import std.conv : to;
import std.stdio : writeln, writefln;

import tagion.hashgraph.Event;
import tagion.Base;
import tango.io.FilePath;

class Backend {

	immutable(FilePath) public_repository;
	private ushort _webserver_port;
	private string[] _webserver_address;
	private ThreadState _thread_state;
	private HTTPListener _listener;
	private const _WEBSOCKET_INTERVALS_MS = 100.msecs;

	//Assumed it is a backend portal with only one connection.
	private WebSocket _currentSocket;

	this(immutable(FilePath) public_repository, ushort webserver_port, string[] webserver_address) {
		this.public_repository = public_repository;
		writeln("Public path to webserver files: ", public_repository.toString);
		this._webserver_address = webserver_address;
		this._webserver_port = webserver_port;
	}


	void startWebserver() {	
		writeln("port: ", _webserver_port);
		auto router = new URLRouter;
		router.get("/", staticRedirect("/index.html"));
		router.get("/ws", handleWebSockets(&handleWebSocketConnection));
		router.get("*", serveStaticFiles(public_repository.toString));

		auto settings = new HTTPServerSettings;
		settings.port = _webserver_port;
		settings.bindAddresses = _webserver_address;
		_listener = listenHTTP(settings, router);
	}

	void stopWebserver() {
		_listener.stopListening;
	}

	void handleWebSocketConnection(scope WebSocket socket)
	{
		_currentSocket = socket;
		int counter = 0;
		logInfo("Got new web socket connection.");
		while (true) {
			sleep(_WEBSOCKET_INTERVALS_MS);
			if (!socket.connected) break;
		}
		logInfo("Client disconnected.");
	}

	void eventCreated (InterfaceEventBody eventBody) {
		if(_currentSocket) {
			auto json = serializeToJsonString(eventBody);
			_currentSocket.send(json);
		}	
	}

	void eventUpdated (InterfaceEventUpdate eventUpdate) {
		if(_currentSocket) {
			auto json = serializeToJsonString(eventUpdate);
			_currentSocket.send(json);
		}
	}
}