module routes.controller;

import vibe.vibe;
import vibe.d;
import vibe.core.core : runApplication;
import vibe.http.server;
import vibe.data.json;

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

// structs
import routes.project.model;

import tagion.hibon.HiBONJSON : toPretty;
import tagion.utils.Miscellaneous : toHexString, decode;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.hibon.HiBONRecord;
import std.digest;
import std.typecons;

public Json[] projectList;
public string filePath = "./source/routes/project/data.json";

struct ResponseModel {
    bool isSucceeded;
    Json data;
}

enum ErrorCode {
    dataNotFound = 11,
    dataNotCorrectType = 12,
    dataBodyNoMatch = 21,
    dataFingerprintNotAdded = 22,
    dataIdWrongLength = 31,
    dataFingerprintNotFound = 32,
}

const struct ErrorResp {
    ErrorCode code;
    string description;
}

Json toJson(ErrorResp err) {
    return serializeToJson(err);
}

void respond(ErrorResp err) {
    const responseModelError = ResponseModel(false, err.toJson);

    res.statusCode = HTTPStatus.badRequest;
    res.writeJsonBody(serializeToJson(responseModelError));
}

/// General Template controller for generating POST, READ and DELETE routes.
struct Controller(T) {

    string name;
    DartService dart_service;
    /** 
     * 
     * Params:
     *   name = name of the type. Used for the routing and fail-handling
     *   router = Reference to the router. For inserting the routes for the POST READ DELETE
     *   dart_service = Reference to the dart_service containing the DART.
     */
    this(const(string) access_token, const(string) name, ref URLRouter router, ref DartService dart_service) {
        this.name = name;
        this.dart_service = dart_service;

        router.get(format("/%s/%s/:entityId", access_token, name), &getT);
        router.delete_(format("/%s/%s/:entityId", access_token, name), &deleteT);
        router.post(format("/%s/%s", access_token, name), &postT);
    }

    /** 
     * Get request for reading specific document. 
     * If the request is not valid according to the recordType we return an error.
     * Params:
     *   req = :entityID. Fingerprint of the Archive stored in the DART.
     *   res = returns the Document
     */
    void getT(HTTPServerRequest req, HTTPServerResponse res) {
        writeln("!!! GET");
        string id = req.params.get("entityId");

        // handle fingerprint exactly 64 characters
        if (id.length != 64) {
            const err = ErrorResp(ErrorCode.dataIdWrongLength, "Provided fingerprint is not valid");
            err.respond;

            return;
        }

        const fingerprint = DARTIndex(decode(id));
        const doc = dart_service.read([fingerprint]);
        if (doc.empty) {
            const err = ErrorResp(ErrorCode.dataNotFound, format("Archive with fingerprint=%s, not found in database", id));
            err.respond;

            return;
        }
        // Check that the document is the Type that was requested.
        if (!isRecord!T(doc.front)) {
            const err = ErrorResp(ErrorCode.dataNotCorrectType, format("Read document not of type=%s", name));
            err.respond;
        }

        T data = T(doc.front);

        const(Json) entity_json = serializeToJson(data);
        ResponseModel responseSuccess = ResponseModel(true, entity_json);
        const(Json) responseSuccessJson = serializeToJson(responseSuccess);

        res.statusCode = HTTPStatus.ok;
        res.writeJsonBody(responseSuccessJson);
    }

    /** 
     * Post the document for the specific type.
     * Takes a json request and converts it to a struct.
     * If the data cannot be converted it throws a json error.
     * Params:
     *   req = json document
     *   res = httpserverresponse
     */
    void postT(HTTPServerRequest req, HTTPServerResponse res) {
        T data;

        // check that user submits correct body
        try {
            data = deserializeJson!T(req.json);
        }
        catch (JSONException e) {
            const err = ErrorResp(ErrorCode.dataBodyNoMatch, format("Request body does not match. JSON struct error, %s", e
                    .msg));

            err.respond;
            return;
        }

        const prev_bullseye = dart_service.bullseye;
        const fingerprint = dart_service.modify(data.toDoc);
        const new_bullseye = dart_service.bullseye;
        if (new_bullseye == prev_bullseye) {
            const err = ErrorResp(ErrorCode.dataFingerprintNotAdded, format(
                    "Entity with fingerprint=%s not added to DART", fingerprint.toHexString));
            err.respond;
            return;
        }

        Json dataSuccess = Json.emptyObject;
        dataSuccess["fingerprint"] = fingerprint.toHexString;

        ResponseModel responseSuccess = ResponseModel(true, dataSuccess);
        const(Json) responseSuccessJson = serializeToJson(responseSuccess);

        res.statusCode = HTTPStatus.created;
        res.writeJsonBody(responseSuccessJson);
    }

    /** 
     * Deletes the fingerprint
     * Params:
     *   req = :entityID. Fingerprint of the Archive stored in the DART.
     *   res = httpresponse.
     */
    void deleteT(HTTPServerRequest req, HTTPServerResponse res) {
        string id = req.params.get("entityId");

        // handle fingerprint exactly 64 characters
        if (id.length != 64) {
            const err = ErrorResp(ErrorCode.dataIdWrongLength, "Provided fingerprint is not valid");
            err.respond;
            return;
        }

        const fingerprint = DARTIndex(decode(id));
        const prev_bullseye = dart_service.bullseye;
        dart_service.remove([fingerprint]);
        const new_bullseye = dart_service.bullseye;

        if (prev_bullseye == new_bullseye) {
            const err = ErrorResp(ErrorCode.dataFingerprintNotFound, format("Entity with fingerprint=%s, not found", fingerprint
                    .toHexString));

            err.respond;
            return;
        }

        Json dataSuccess = Json.emptyObject;
        dataSuccess["message"] = "Succesfully deleted";

        ResponseModel responseSuccess = ResponseModel(true, dataSuccess);
        const(Json) responseSuccessJson = serializeToJson(responseSuccess);

        // res.writeBody(format("Entity with fingerprint=%s deleted", fingerprint.toHexString));
        res.statusCode = HTTPStatus.ok;
        res.writeJsonBody(responseSuccessJson);
    }
}
