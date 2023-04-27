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

import routes.controller : Controller;

import routes.project.model;
import routes.projectDocument.model;
import routes.benefitShareCredit.model;
import routes.benefitShare.model;
import routes.benefit.model;
import routes.documentDocument.model;
import std.file;

void main() {
    auto router = new URLRouter;
    const filename = "/tmp/dart.drt";
    if (!filename.exists) {
        DARTFile.create(filename);
    }

    DartService dart_service = DartService(filename, "very_secret");

    auto controller_project = Controller!Project("project", router, dart_service);
    auto controller_benefit_share_credit = Controller!BenefitShareCredit("benefit_share_credit", router, dart_service);
    auto controller_benefit_share = Controller!BenefitShare("benefit_share", router, dart_service);
    auto controller_project_document = Controller!ProjectDocument("project_document", router, dart_service);
    auto controller_document = Controller!DocumentDocument("document", router, dart_service);
    auto controller_benefit = Controller!Benefit("benefit", router, dart_service);

    foreach(route; router.getAllRoutes) {
        writeln(route);
    }



    // Controller!BenefitShareCredit 
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
