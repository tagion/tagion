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
import std.file;

import services.dartService;
import tagion.dart.DARTFile;

// controllers
import source.controller : Controller;

// models
import source.models.project;
import source.models.projectDocument;
import source.models.benefit;
import source.models.benefitShare;
import source.models.benefitShareCredit;
import source.models.documentDocument;
import source.models.other : Route;

const revision = import("revision.txt");

void main() {
    auto router = new URLRouter;

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

    foreach (route; router.getAllRoutes) {
        logInfo(format("(%s) %s", route.method, route.pattern));
    }

    // Create a vibe.d HTTP server
    auto settings = new HTTPServerSettings;
    settings.port = 8081;
    settings.bindAddresses = ["::1", "127.0.0.1"];

    listenHTTP(settings, router);

    logInfo("Running revision: %s", revision);
    logInfo("Open http://127.0.0.1:8081/ in your browser.");

    runApplication();
}
