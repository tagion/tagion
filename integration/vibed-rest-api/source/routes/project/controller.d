module routes.project.controller;

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
import std.stdio : writefln;
import std.format;
import std.json : JSONException;

import services.routerService;
import services.fsService;
import services.dartService;

import routes.project.model;

import tagion.hibon.HiBONJSON : toPretty;
import tagion.utils.Miscellaneous : toHexString, decode;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.hibon.HiBONRecord;
import std.digest;

public Json[] projectList;
public string filePath = "./source/routes/project/data.json";

struct Controller {
    DartService dart_service;
    this(const(string) dart_filename, const(string) password) {
        dart_service = DartService(dart_filename, password);
    }

    void getProject(HTTPServerRequest req, HTTPServerResponse res) {
        string id = req.params.get("entityId");

        const fingerprint = DARTIndex(decode(id));
        const doc = dart_service.read([fingerprint]);
        if (doc.empty) {
            res.statusCode = HTTPStatus.badRequest;
            res.writeBody(format("Archive with fingerprint=%s, not found in database", id));
            return;
        }
        // cannot use compile time for some reason.
        if (!isRecord!Project(doc.front)) {
            res.statusCode = HTTPStatus.badRequest;
            res.writeBody(format("Read document not of type=Project"));
        }

        Project project_data = Project(doc.front);
        const(Json) project_json = serializeToJson(project_data);

        res.writeJsonBody(project_json);
        res.statusCode = HTTPStatus.ok;

    }

    void postProject(HTTPServerRequest req, HTTPServerResponse res) {
        // handle bullseye change in order to make sure that an archive was added.
        struct PostResponse {
            string id;
        }

        Project project_data;

        // check that user submits correct body
        try {
            project_data = deserializeJson!Project(req.json);
        }
        catch (JSONException e) {
            res.statusCode = HTTPStatus.badRequest;
            res.writeBody(format("Request body does not match. JSON struct error, %s", e.msg));
            return;
        }

        const prev_bullseye = dart_service.bullseye;
        const fingerprint = dart_service.modify(project_data.toDoc);
        const new_bullseye = dart_service.bullseye;
        if (new_bullseye == prev_bullseye) {
          res.statusCode = HTTPStatus.badRequest;
          res.writeBody(format("Project with fingerprint=%s not added to DART", fingerprint.toHexString));
        }

        PostResponse postResponse;
        postResponse.id = fingerprint.toHexString;

        res.statusCode = HTTPStatus.created;
        res.writeJsonBody(postResponse);
    }

    void deleteProject(HTTPServerRequest req, HTTPServerResponse res) {
        string id = req.params.get("entityId");
        const prev_bullseye = dart_service.bullseye;
        const fingerprint = DARTIndex(decode(id));
        dart_service.remove([fingerprint]);
        const new_bullseye = dart_service.bullseye;

        if (prev_bullseye == new_bullseye) {
          res.statusCode = HTTPStatus.badRequest;
          res.writeBody(format("Project with fingerprint=%s, not found", fingerprint.toHexString));
          return;
        }
        res.statusCode = HTTPStatus.ok;
        res.writeBody(format("Project with fingerprint=%s deleted", fingerprint.toHexString));
    }
}
