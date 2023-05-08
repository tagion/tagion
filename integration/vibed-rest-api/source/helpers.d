module source.helpers;

import std.random;
import std.conv;
import std.stdio;
import std.format;
import std.range;

import vibe.data.json;
import vibe.http.server;
import vibe.http.router;

import source.models.other : ResponseModel, ErrorResponse;

void setCORSHeaders(HTTPServerResponse res) {
    res.headers["Access-Control-Allow-Origin"] = "*"; // "https://editor.swagger.io, https://docs.decard.io"
    res.headers["Access-Control-Allow-Headers"] = "*"; // "Origin, X-Requested-With, Content-Type, Accept";
    res.headers["Access-Control-Allow-Methods"] = "*"; // "GET, POST, PUT, DELETE, OPTIONS";
    res.headers["Access-Control-Max-Age"] = "86400";
}

void respondWithError(HTTPServerResponse res, ErrorResponse err) {
    const responseModelError = ResponseModel(false, serializeToJson(err));

    const(Json) responseModelErrorJson = serializeToJson(responseModelError);

    writeln("responseModelErrorJson: ", responseModelErrorJson);

    setCORSHeaders(res);
    res.statusCode = HTTPStatus.badRequest;
    res.writeJsonBody(responseModelErrorJson);
}

void handleServerError(HTTPServerResponse res, HTTPServerRequest req, Exception exception) {
    auto rnd = rndGen;

    const errorId = rnd.take(64).sum;

    const err = ErrorResponse(HTTPStatus.internalServerError, "Internal Server Error, id: %s".format(
            errorId));
    const errJson = serializeToJson(err);

    logError(format("%s", err));
    logError(req.toString);
    logError(exception.toString);

    const responseModelErr = ResponseModel(false, errJson);

    setCORSHeaders(res);
    res.statusCode = HTTPStatus.internalServerError;
    res.writeJsonBody(serializeToJson(responseModelErr));
}

auto tryReqHandler(void delegate(HTTPServerRequest, HTTPServerResponse) fn) {
    return (HTTPServerRequest req, HTTPServerResponse res) {
        try {
            fn(req, res);
        }
        catch (Exception e) {
            res.handleServerError(req, e);
        }
    };
}