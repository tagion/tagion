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
import std.random;
import std.range : take;

struct ResponseModel {
    bool isSucceeded;
    Json data;
}

enum ErrorCode {
    dataIdWrongLength = 11,
    dataNotFound = 12,
    dataNotCorrectType = 13,
    dataBodyNoMatch = 21,
    dataFingerprintNotAdded = 22,
    dataFingerprintNotFound = 31,
}

enum ErrorDescription {
    dataIdWrongLength = "Provided fingerprint is not valid",
    dataNotFound = "Archive with fingerprint not found in database",
    dataNotCorrectType = "Wrong document type",
    dataBodyNoMatch = "Request body does not match",
    dataFingerprintNotAdded = "Entity with fingerprint not added to DART",
    dataFingerprintNotFound = "Entity with fingerprint not found",
}

struct ErrorResponse {
    int errorCode;
    string errorDescription;
}

auto tryReqHandler(void delegate(HTTPServerRequest, HTTPServerResponse) fn) {
    return (HTTPServerRequest req, HTTPServerResponse res) {
        try {
            fn(req, res);
        }
        catch (Exception e) {
            res.handleServerError(e);
        }
    };
}

void respond(HTTPServerResponse res, ErrorResponse err) {
    const responseModelError = ResponseModel(false, serializeToJson(err));

    res.statusCode = HTTPStatus.badRequest;
    res.writeJsonBody(serializeToJson(responseModelError));
}

void handleServerError(HTTPServerResponse res, Exception exception) {
    auto rnd = rndGen;

    const errorId = rnd.take(64).sum;

    const err = ErrorResponse(HTTPStatus.internalServerError, "Internal Server Error, id: %s".format(errorId));
    const errJson = serializeToJson(err);

    stderr.writeln(err);
    stderr.writeln(exception);

    const responseModelErr = ResponseModel(false, errJson);

    res.statusCode = HTTPStatus.internalServerError;
    res.writeJsonBody(serializeToJson(responseModelErr));
}

/// General Template controller for generating POST, READ and DELETE routes.
struct Controller(T) {
    string name;
    DartService dart_service;

    void setCORSHeaders(HTTPServerResponse res) {
        res.headers["Access-Control-Allow-Origin"] = "*";
        // res.headers["Access-Control-Allow-Origin"] = "https://editor.swagger.io, https://docs.decard.io";
        res.headers["Access-Control-Allow-Headers"] = "*";
        // res.headers["Access-Control-Allow-Headers"] = "Origin, X-Requested-With, Content-Type, Accept";
        res.headers["Access-Control-Allow-Methods"] = "*";
        // res.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS";
        res.headers["Access-Control-Max-Age"] = "86400";
    }

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

        // // Handle CORS
        // router.any("*", delegate void(scope HTTPServerRequest req, scope HTTPServerResponse res) {
        //   writeln("req.method: ", req.method);

        //   if (req.method == HTTPRequest.method.OPTIONS) {
        //     writeln("req.method == HTTPRequest.method.OPTIONS");
        //     res.statusCode = HTTPStatus.ok;
        //   }

        //   res.headers["Access-Control-Allow-Origin"] = "*";
        //   // res.headers["Access-Control-Allow-Origin"] = "https://editor.swagger.io, https://docs.decard.io";
        //   // res.headers["Access-Control-Allow-Headers"] = "Origin, X-Requested-With, Content-Type, Accept";
        //   res.headers["Access-Control-Allow-Headers"] = "*";
        //   // res.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS";
        //   res.headers["Access-Control-Allow-Methods"] = "*";
        //   res.headers["Access-Control-Max-Age"] = "86400";
        //   res.statusCode = HTTPStatus.ok;
        // });

        void optionsHandler(HTTPServerRequest req, HTTPServerResponse res) {
            writeln("req.method: ", req.method);

            if (req.method == HTTPRequest.method.OPTIONS) {
                writeln("req.method == HTTPRequest.method.OPTIONS");
                res.statusCode = HTTPStatus.ok;
            }

            setCORSHeaders(res);
            res.statusCode = HTTPStatus.noContent;
            res.writeBody("smth!");
        }

        router.match(HTTPMethod.OPTIONS, "*", tryReqHandler(&optionsHandler));
        router.get(format("/%s/%s/:entityId", access_token, name), tryReqHandler(&getT));
        // router.delete_(format("/%s/%s/:entityId", access_token, name), tryReqHandler(&deleteT));
        router.post(format("/%s/%s", access_token, name), tryReqHandler(&postT));
    }

    // void optionsHandler(HTTPServerRequest req, HTTPServerResponse res) {
    //   if (req.method == HTTPRequest.method.OPTIONS) {
    //     res.statusCode = HTTPStatus.ok;
    //   }

    //   res.headers["Access-Control-Allow-Origin"] = "*";
    //   res.headers["Access-Control-Allow-Headers"] = "*";
    //   res.headers["Access-Control-Allow-Methods"] = "*";
    //   res.headers["Access-Control-Max-Age"] = "86400";
    //   res.statusCode = HTTPStatus.ok;
    // }

    // router.match(HTTPMethod.OPTIONS, "*", &optionsHandler);
    // router.get("/items", getHandler);
    // router.post("/items", getHandler);
    // router.delete("/items", getHandler);

    /**
     * Get request for reading specific document.
     * If the request is not valid according to the recordType we return an error.
     * Params:
     *   req = :entityID. Fingerprint of the Archive stored in the DART.
     *   res = returns the Document
     */
    void getT(HTTPServerRequest req, HTTPServerResponse res) {

        writeln("GET");
        string id = req.params.get("entityId");

        // handle fingerprint exactly 64 characters
        if (id.length != 64) {
            const err = ErrorResponse(ErrorCode.dataIdWrongLength, ErrorDescription.dataIdWrongLength);
            res.respond(err);
            return;
        }

        const fingerprint = DARTIndex(decode(id));
        const doc = dart_service.read([fingerprint]);
        if (doc.empty) {
            const err = ErrorResponse(ErrorCode.dataNotFound, ErrorDescription.dataNotFound);

            res.respond(err);
            return;
        }
        // Check that the document is the Type that was requested.
        if (!isRecord!T(doc.front)) {
            const err = ErrorResponse(ErrorCode.dataNotCorrectType, ErrorDescription.dataNotCorrectType);
            res.respond(err);
        }

        T data = T(doc.front);

        const(Json) entity_json = serializeToJson(data);
        ResponseModel responseSuccess = ResponseModel(true, entity_json);
        const(Json) responseSuccessJson = serializeToJson(responseSuccess);

        setCORSHeaders(res);
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
        writeln("POST");

        T data;

        // check that user submits correct body
        try {
            data = deserializeJson!T(req.json);

            writeln("data: ", data);
        }
        catch (JSONException e) {
            const err = ErrorResponse(ErrorCode.dataBodyNoMatch, ErrorDescription.dataBodyNoMatch);

            res.respond(err);
            return;
        }

        const prev_bullseye = dart_service.bullseye;
        const fingerprint = dart_service.modify(data.toDoc);
        const new_bullseye = dart_service.bullseye;
        if (new_bullseye == prev_bullseye) {
            const err = ErrorResponse(ErrorCode.dataFingerprintNotAdded, ErrorDescription.dataFingerprintNotAdded);
            res.respond(err);
            return;
        }

        Json dataSuccess = Json.emptyObject;
        dataSuccess["fingerprint"] = fingerprint.toHexString;

        ResponseModel responseSuccess = ResponseModel(true, dataSuccess);
        const(Json) responseSuccessJson = serializeToJson(responseSuccess);

        setCORSHeaders(res);
        res.statusCode = HTTPStatus.created;
        res.writeJsonBody(responseSuccessJson);
    }

    /**
     * Deletes the fingerprint
     * Params:
     *   req = :entityID. Fingerprint of the Archive stored in the DART.
     *   res = httpresponse.
     */
    // void deleteT(HTTPServerRequest req, HTTPServerResponse res) {
    //     writeln("DELETE");

    //     string id = req.params.get("entityId");

    //     // handle fingerprint exactly 64 characters
    //     if (id.length != 64) {
    //         const err = ErrorResponse(ErrorCode.dataIdWrongLength, ErrorDescription.dataIdWrongLength);
    //         res.respond(err);
    //         return;
    //     }

    //     const fingerprint = DARTIndex(decode(id));
    //     const prev_bullseye = dart_service.bullseye;
    //     dart_service.remove([fingerprint]);
    //     const new_bullseye = dart_service.bullseye;

    //     if (prev_bullseye == new_bullseye) {
    //         const err = ErrorResponse(ErrorCode.dataFingerprintNotFound, ErrorDescription.dataFingerprintNotFound);

    //         res.respond(err);
    //         return;
    //     }

    //     Json dataSuccess = Json.emptyObject;
    //     dataSuccess["message"] = "Succesfully deleted";

    //     ResponseModel responseSuccess = ResponseModel(true, dataSuccess);
    //     const(Json) responseSuccessJson = serializeToJson(responseSuccess);

    //     setCORSHeaders(res);
    //     // res.writeBody(format("Entity with fingerprint=%s deleted", fingerprint.toHexString));
    //     res.statusCode = HTTPStatus.ok;
    //     res.writeJsonBody(responseSuccessJson);
    // }
}
