module source.generic_controller;

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
import tagion.utils.Miscellaneous : toHexString;

import tagion.hibon.HiBONtoText;
import tagion.basic.Types;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;

// services
import services.dartService;

// models
import source.models.other : ResponseModel, ErrorResponse, ErrorCode, ErrorDescription;

import source.helpers : setCORSHeaders, respondWithError, handleServerError, tryReqHandler;

/// General Template controller for generating POST, GET and DELETE routes.
struct GenericController {
    string name;
    DartService dart_service;

    /**
     *
     * Params:
     *   name = name of the type. Used for the routing and fail-handling
     *   router = Reference to the router. For inserting the routes for the POST READ DELETE
     *   dart_service = Reference to the dart_service containing the DART.
     */
    this(const(string) access_token, ref URLRouter router, ref DartService dart_service) {
        this.name = name;
        this.dart_service = dart_service;

        router.match(HTTPMethod.OPTIONS, "*", tryReqHandler(&optionsHandler));
        router.get(format("/%s/:entityId", access_token), tryReqHandler(&getT));
        router.post(format("/%s/:data", access_token), tryReqHandler(&postT));
        router.post(format("/%s", access_token), tryReqHandler(&postJSONT)); 
    }

    /**
     * Get request for reading specific document.
     * Params:
     *   req = :entityID. Fingerprint of the Archive stored in the DART.
     *   res = returns the Document
     */
    void getT(HTTPServerRequest req, HTTPServerResponse res) {
        import tagion.hibon.HiBONJSON : toJSON;
        writeln("GET");

        string id = req.params.get("entityId");

        DARTIndex fingerprint;
        try {
            // if (id.length != 64) {
            //     throw new Exception("Length is not correct");
            // }
            fingerprint = DARTIndex(decode(id));
        }
        catch (Exception e) {
            const err = ErrorResponse(ErrorCode.dataIdnotValid, ErrorDescription
                    .dataIdnotValid);
            respondWithError(res, err);
            return;
        }

        const doc = dart_service.read([fingerprint]);
        if (doc.empty) {
            const err = ErrorResponse(ErrorCode.dataNotFound, ErrorDescription.dataNotFound);

            respondWithError(res, err);
            return;
        }

        const(Json) entity_json = toJSON(doc.front);
         

        ResponseModel responseSuccess = ResponseModel(true, entity_json);
        const(Json) responseSuccessJson = serializeToJson(responseSuccess);

        writeln("responseSuccessJson: ", responseSuccessJson);

        setCORSHeaders(res);
        res.statusCode = HTTPStatus.ok;
        res.writeJsonBody(responseSuccessJson);
    }

    /**
     * Post the document as base64.
     * If the data cannot be converted it throws a json error.
     * Params:
     *   req = json document
     *   res = httpserverresponse
     */
    void postT(HTTPServerRequest req, HTTPServerResponse res) {
        import tagion.hibon.HiBONJSON;
        writeln("POST");

        Document doc;
        const data = req.params.get("data");

        writeln("data: ", data);
        try {
            doc = decodeBase64(data);
        } catch (Exception e) {
            const err = ErrorResponse(ErrorCode.dataNotValid, ErrorDescription.dataNotValid);
            writeln("ErrorDescription.dataNotValid");
            respondWithError(res, err);
            return;
        }
        writeln(doc.toPretty);
        const fingerprint = dart_service.modify(doc);

        Json dataSuccess = Json.emptyObject;
        const buf = cast(Buffer) fingerprint;
        dataSuccess["fingerprint"] = buf.encodeBase64;

        ResponseModel responseSuccess = ResponseModel(true, dataSuccess);

        const(Json) responseSuccessJson = serializeToJson(responseSuccess);

        writeln("responseSuccessJson: ", responseSuccessJson);

        setCORSHeaders(res);
        res.statusCode = HTTPStatus.created;
        res.writeJsonBody(responseSuccessJson);
        res.statusCode = HTTPStatus.created;
    }

    void postJSONT(HTTPServerRequest req, HTTPServerResponse res) {
        import tagion.hibon.HiBONJSON : toHiBON;
        import stdjson = std.json;
        writeln("POST JSON");
        Document doc;

        try {
            const text = req.json.toString;
            const json = stdjson.parseJSON(text);
            doc = Document(toHiBON(json));

            writeln("doc: ", doc);
        }
        catch (Exception e) {
            const err = ErrorResponse(ErrorCode.dataNotValid, ErrorDescription.dataNotValid);
            writeln("ErrorDescription.dataNotValid");
            respondWithError(res, err);
            return;
        }

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


