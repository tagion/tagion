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
import bakery.Base;

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

	bool runBackend = true;

	void handleState (SetThreadState ts) {
		with(SetThreadState) final switch(ts) {
					case KILL:
						writeln("Kill webserver");
						runBackend = false;
					break;

					case LIVE:
						runBackend = true;
					break;
				}
	}

    while(runBackend) {
        receive(
			//Control the thread
			&handleState,

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