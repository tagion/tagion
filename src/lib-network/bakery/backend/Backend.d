module bakery.backend.Backend;

import vibe.core.core : sleep;
import vibe.core.log;
import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.http.websockets : WebSocket, handleWebSockets;

import core.time;
import std.concurrency;
import std.conv : to;
import std.stdio : writeln;

import bakery.hashgraph.Event;

enum EventProperty {
	STRONGLY_SEEING,
	IS_FAMOUS,
	IS_WITNESS
};

immutable struct InterfaceEventUpdate {
    uint id;
	EventProperty property;
	bool value;

    this(uint id, EventProperty property, bool value) {
        this.id = id;
        this.property = property;
        this.value = value;
    }
}

immutable struct InterfaceEventBody {
    uint id;
    uint motherId;
	uint fatherId;
	ubyte[] payload;

    this(immutable(uint) id, 
	immutable(ubyte[]) payload,
	immutable(uint) motherId = 0, 
	immutable(uint) fatherId = 0
	) {
        this.id = id;
        this.motherId = motherId;
		this.fatherId = fatherId;
		this.payload = payload;
    }
}

void startWebserver() {
    auto router = new URLRouter;
	router.get("/", staticRedirect("/index.html"));
	router.get("/ws", handleWebSockets(&handleWebSocketConnection));
	router.get("*", serveStaticFiles("../../backend_tools/public/"));

	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	auto listener = listenHTTP(settings, router);

	scope(exit) listener.stopListening;

    for (;;) {
        receive(
            (string msg) {
             writeln("Received the message: " , msg);
            }
			
        );
    }

    

}



void handleWebSocketConnection(scope WebSocket socket)
{
	int counter = 0;
	logInfo("Got new web socket connection.");
	while (true) {
		sleep(1.seconds);
		if (!socket.connected) break;
		counter++;
		logInfo("Sending '%s'.", counter);
		socket.send(counter.to!string);
	}
	logInfo("Client disconnected.");
}