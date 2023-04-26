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

import routes.project.controller;

void main() {
  auto router = new URLRouter;

  // Define routes
  router.get("/project", &getAllProjects);
  router.get("/project/:entityId", &getOneProject);
  router.delete_("/project/:entityId", &deleteOneProject);
  router.post("/project", &postProject);

  // Create a vibe.d HTTP server
	auto settings = new HTTPServerSettings;
	settings.port = 8081;
	settings.bindAddresses = ["::1", "127.0.0.1"];
  
  // listen to server
	listenHTTP(settings, router);
	logInfo("Open http://127.0.0.1:8081/ in your browser.");
	runApplication();
}
