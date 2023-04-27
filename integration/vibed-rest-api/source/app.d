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
    // const filename = "/tmp/dart.drt";

    const string[] access_tokens = [
        "test", "VENZOtar2ns4teitc4cxn39tsdei9mdt95eitars890354mvst9dn44",
    ];

    const test_token = access_tokens[0];
    const test_filename = format("%s-dart.drt", test_token);

    if (!test_filename.exists) {
        DARTFile.create(test_filename);
    }

    auto test_dart_service = DartService(test_filename, test_token);
    auto test_project = Controller!Project(test_token, "project", router, test_dart_service);
    auto test_benefit_share_credit = Controller!BenefitShareCredit(test_token, "benefit_share_credit", router, test_dart_service);
    auto test_benefit_share = Controller!BenefitShare(test_token, "benefit_share", router, test_dart_service);
    auto test_project_document = Controller!ProjectDocument(test_token, "project_document", router, test_dart_service);
    auto test_document = Controller!DocumentDocument(test_token, "document", router, test_dart_service);
    auto test_benefit = Controller!Benefit(test_token, "benefit", router, test_dart_service);

    const venzo_token = access_tokens[1];
    const venzo_filename = format("%s-dart.drt", venzo_token);

    if (!venzo_filename.exists) {
        DARTFile.create(venzo_filename);
    }

    auto venzo_dart_service = DartService(test_filename, venzo_token);
    auto venzo_project = Controller!Project(venzo_token, "project", router, venzo_dart_service);
    auto venzo_benefit_share_credit = Controller!BenefitShareCredit(venzo_token, "benefit_share_credit", router, venzo_dart_service);
    auto venzo_benefit_share = Controller!BenefitShare(venzo_token, "benefit_share", router, venzo_dart_service);
    auto venzo_project_document = Controller!ProjectDocument(venzo_token, "project_document", router, venzo_dart_service);
    auto venzo_document = Controller!DocumentDocument(venzo_token, "document", router, venzo_dart_service);
    auto venzo_benefit = Controller!Benefit(venzo_token, "benefit", router, venzo_dart_service);

    foreach (route; router.getAllRoutes) {
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
