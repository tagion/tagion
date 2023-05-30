module controller;

import vibe.http.server;
import vibe.http.router;
import vibe.data.json;
import vibe.core.log;

import std.array;
import std.stdio;
import std.conv;
import std.algorithm;
import std.stdio : writefln;
import std.format;
import std.digest;
import std.typecons;
import std.random;
import std.range : take;

import tagion.hibon.HiBONJSON : toPretty;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.utils.Miscellaneous : toHexString, decode;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;

// services
import services.dartService;

// models
import models.other : ResponseModel, ErrorResponse, ErrorCode, ErrorDescription;

import helpers : setCORSHeaders, respondWithError, handleServerError, tryReqHandler;

/// General Template controller for generating POST, GET and DELETE routes.
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

        router.match(HTTPMethod.OPTIONS, "*", tryReqHandler(&optionsHandler));
        router.get(format("/%s/%s/:entityId", access_token, name), tryReqHandler(&getT));
        // router.delete_(format("/%s/%s/:entityId", access_token, name), tryReqHandler(&deleteT));
        router.post(format("/%s/%s", access_token, name), tryReqHandler(&postT));
    }

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

        DARTIndex fingerprint;
        try {
            if (id.length != 64) {
                throw new Exception("Length is not correct");
            }
            fingerprint = DARTIndex(decode(id));
        }
        catch (Exception e) {
            const err = ErrorResponse(ErrorCode.dataIdnotValid, ErrorDescription
                    .dataIdnotValid);
            respondWithError(res, err);
            return;
        }

        // const fingerprint = DARTIndex(decode(id));
        const doc = dart_service.read([fingerprint]);
        if (doc.empty) {
            const err = ErrorResponse(ErrorCode.dataNotFound, ErrorDescription.dataNotFound);

            respondWithError(res, err);
            return;
        }
        // Check that the document is the Type that was requested.
        if (!isRecord!T(doc.front)) {
            const err = ErrorResponse(ErrorCode.dataNotCorrectType, ErrorDescription.dataNotCorrectType);
            respondWithError(res, err);
            return;
        }

        T data = T(doc.front);

        const(Json) entity_json = serializeToJson(data);
        ResponseModel responseSuccess = ResponseModel(true, entity_json);
        const(Json) responseSuccessJson = serializeToJson(responseSuccess);

        writeln("responseSuccessJson: ", responseSuccessJson);

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
        Document doc;
        // check that user submits correct body
        try {
            // writefln("data before conversion JSON: %s", req.json);
            data = deserializeJson!T(req.json);

            doc = data.toDoc;
        }
        catch (Exception e) {
            const err = ErrorResponse(ErrorCode.dataBodyNoMatch, ErrorDescription.dataBodyNoMatch);
            writeln("ErrorDescription.dataBodyNoMatch");
            respondWithError(res, err);
            return;
        }

        // writefln("data converted document=%s", doc.toPretty);
        const prev_bullseye = dart_service.bullseye;

        const fingerprint = dart_service.modify(doc);
        const new_bullseye = dart_service.bullseye;
        if (new_bullseye == prev_bullseye) {
            const err = ErrorResponse(ErrorCode.dataFingerprintNotAdded, ErrorDescription
                    .dataFingerprintNotAdded);
            writeln("ErrorDescription.dataFingerprintNotAdded");
            respondWithError(res, err);
            return;
        }

        Json dataSuccess = Json.emptyObject;
        dataSuccess["fingerprint"] = fingerprint.toHexString;

        ResponseModel responseSuccess = ResponseModel(true, dataSuccess);

        const(Json) responseSuccessJson = serializeToJson(responseSuccess);

        writeln("responseSuccessJson: ", responseSuccessJson);

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
    //         const err = ErrorResponse(ErrorCode.dataIdnotValid, ErrorDescription.dataIdnotValid);
    //         respondWithError(res, err);
    //         return;
    //     }

    //     const fingerprint = DARTIndex(decode(id));
    //     const prev_bullseye = dart_service.bullseye;
    //     dart_service.remove([fingerprint]);
    //     const new_bullseye = dart_service.bullseye;

    //     if (prev_bullseye == new_bullseye) {
    //         const err = ErrorResponse(ErrorCode.dataFingerprintNotFound, ErrorDescription.dataFingerprintNotFound);

    //         respondWithError(res, err);
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

    void optionsHandler(HTTPServerRequest req, HTTPServerResponse res) {
      // handle CORS and response for preflight requests
      if (req.method == HTTPRequest.method.OPTIONS) {
        writeln("req.method == HTTPRequest.method.OPTIONS");
        setCORSHeaders(res);
        res.statusCode = HTTPStatus.ok;
      }

      setCORSHeaders(res);
      res.statusCode = HTTPStatus.noContent;
      writeln("res.statusCode", res.statusCode);
      writeln("res.headers", res.headers);
      res.writeBody("no content");
    }
}



// post as normal to ex: /project/blabla
// take the route name and add it to the json called hibontype
// deserialize the struct including the hibontype
// store it in the dart.


// read generic
// take the hibontype from the hibon file. if there is no type but there is a document return the hibonjson format
// use the name to get the struct and deserialize accordingly.

// read project
