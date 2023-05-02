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

import routes.controller : Controller;

import routes.project.model;
import routes.projectDocument.model;
import routes.benefitShareCredit.model;
import routes.benefitShare.model;
import routes.benefit.model;
import routes.documentDocument.model;
import std.file;

const revision = import("revision.txt");

// void index(HTTPServerRequest req, HTTPServerResponse res)
// {
// 	res.render!("index.html", req);
// }

void main() {
    auto router = new URLRouter;
    // const filename = "/tmp/dart.drt";

    enum Route {
      project = "project",
      benefit_share_credit = "benefit-share-credit",
      benefit_share = "benefit-share",
      project_document = "project-document",
      document = "document",
      benefit = "benefit",
    }

    // access tokens
    const string[] access_tokens = [
        "test", "VENZOtar2ns4teitc4cxn39tsdei9mdt95eitars890354mvst9dn44",
    ];

    const test_token = access_tokens[0];
    const test_filename = format("%s-dart.drt", test_token);

    if (!test_filename.exists) {
        DARTFile.create(test_filename);
    }

    const venzo_token = access_tokens[1];
    const venzo_filename = format("%s-dart.drt", venzo_token);

    if (!venzo_filename.exists) {
        DARTFile.create(venzo_filename);
    }

    auto test_dart_service = DartService(test_filename, test_token);
    auto test_project = Controller!Project(test_token, Route.project, router, test_dart_service);
    auto test_benefit_share_credit = Controller!BenefitShareCredit(test_token, Route.benefit_share_credit, router, test_dart_service);
    auto test_benefit_share = Controller!BenefitShare(test_token, Route.benefit_share, router, test_dart_service);
    auto test_project_document = Controller!ProjectDocument(test_token, Route.project_document, router, test_dart_service);
    auto test_document = Controller!DocumentDocument(test_token, Route.document, router, test_dart_service);
    auto test_benefit = Controller!Benefit(test_token, Route.benefit, router, test_dart_service);

    auto venzo_dart_service = DartService(venzo_filename, venzo_token);
    auto venzo_project = Controller!Project(venzo_token, Route.project, router, venzo_dart_service);
    auto venzo_benefit_share_credit = Controller!BenefitShareCredit(venzo_token, Route.benefit_share_credit, router, venzo_dart_service);
    auto venzo_benefit_share = Controller!BenefitShare(venzo_token, Route.benefit_share, router, venzo_dart_service);
    auto venzo_project_document = Controller!ProjectDocument(venzo_token, Route.project_document, router, venzo_dart_service);
    auto venzo_document = Controller!DocumentDocument(venzo_token, Route.document, router, venzo_dart_service);
    auto venzo_benefit = Controller!Benefit(venzo_token, Route.benefit, router, venzo_dart_service);

    // Add a route to serve the index.html file
    foreach (route; router.getAllRoutes) {
        logInfo(format("(%s) %s", route.method, route.pattern));
    }

    // Create a vibe.d HTTP server
    auto settings = new HTTPServerSettings;
    settings.port = 8081;
    settings.bindAddresses = ["::1", "127.0.0.1"];

    logInfo("Running revision: %s", revision);
    // listen to server
    listenHTTP(settings, router);
    logInfo("Open http://127.0.0.1:8081/ in your browser.");

    runApplication();
}
