module app;

import vibe.vibe;
import vibe.d;
import vibe.core.core : runApplication;
import vibe.http.server;
import vibe.data.json;

import std.json;
import std.array;
import std.stdio;
import std.conv;
import std.algorithm;
import std.file : exists;

import services.dartService;
import tagion.dart.DARTFile;
import routes.project.model;


import routes.project.controller : Controller;

void main() {
  auto router = new URLRouter;
  const filename = "/tmp/dart.drt";
  if (!filename.exists) {
    DARTFile.create(filename);
  }   

  Controller!Project controller = Controller!Project("Project", router, filename, "very_secret");
  // Define routes


  // Create a vibe.d HTTP server
	auto settings = new HTTPServerSettings;
	settings.port = 8081;
	settings.bindAddresses = ["::1", "127.0.0.1"];
  

  // listen to server
	listenHTTP(settings, router);
	logInfo("Open http://127.0.0.1:8081/ in your browser.");
	runApplication();
}
