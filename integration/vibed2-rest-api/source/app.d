module app;

import vibe.core.core : runApplication;
import vibe.http.server;
import vibe.http.router;
import vibe.data.json;
import vibe.core.log;

import std.json;
import std.array;
import std.stdio;
import std.conv;
import std.algorithm;
import std.file : exists;
import std.format;

import services.dartService;
import tagion.dart.DARTFile;

// controllers
import source.generic_controller : GenericController;

// const revision = import("revision.txt");

void main() {
    auto router = new URLRouter;

    // access tokens
    const string[] access_tokens = [
        "test",
    ];

    const test_token = access_tokens[0];
    const test_filename = format("%s-dart.drt", test_token);

    auto test_dart_service = DartService(test_filename, test_token);

    auto test_project = GenericController(test_token, router, test_dart_service);

    foreach (route; router.getAllRoutes) {
        logInfo(format("(%s) %s", route.method, route.pattern));
    }

    // Create a vibe.d HTTP server
    auto settings = new HTTPServerSettings;
    settings.port = 8081;
    settings.bindAddresses = ["::1", "0.0.0.0"];

    listenHTTP(settings, router);

    // logInfo("Running revision: %s", revision);
    logInfo("Open http://0.0.0.0:8081/ in your browser.");

    runApplication();
}
