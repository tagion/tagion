module services.routerService;

import vibe.http.server;
import vibe.data.json;

import std.json;
import std.array;
import std.stdio;
import std.conv;
import std.algorithm;
import std.format;

import services.fsService;

void getAll(HTTPServerRequest req, HTTPServerResponse res, Json[] entityList, string filePath) {
    entityList = readFromFile(filePath);

    res.headers["Content-Type"] = "application/json";
    res.writeJsonBody(entityList);
}

void getOne(HTTPServerRequest req, HTTPServerResponse res, Json[] entityList, string filePath, string entityId) {
    entityList = readFromFile(filePath);

    string id = req.params.get("entityId");
    string messageNotFound = format("Object with ID %s not found", id);

    if (entityList.length > 0) {
        foreach (key, value; entityList) {
            if (value[entityId] == id) {
                writeln("Object with specific ID found");
                res.writeJsonBody(value);
                return;
            }
        }

        res.statusCode = HTTPStatus.notFound;
        res.writeBody(messageNotFound);
    }
    else {
        res.statusCode = HTTPStatus.notFound;
        res.writeBody(messageNotFound);
        return;
    }
}

// void post(HTTPServerRequest req, HTTPServerResponse res, Json[] entityList, string filePath) {
// TODO: pass struct as function parameter
// }

// void deleteOne(HTTPServerRequest req, HTTPServerResponse res, Json[] entityList, string filePath, string entityId) {
//     string id = req.params.get("entityId");
//     string messageNotFound = format("Object with ID %s not found", id);

//     entityList = readFromFile(filePath);

//     if (entityList.length > 0) {
//       foreach(key, value; entityList) {
//         if (value[entityId] == id) {
//           entityList = entityList.filter!(entityJson => entityJson[entityId] != value[entityId]).array;

//           writeToFile(entityList, filePath);

//           writeln("Object with specific ID deleted");
//           res.writeJsonBody(value);
//           return;
//         }
//       }

//       res.statusCode = HTTPStatus.notFound;
//       res.writeBody(messageNotFound);
//     } else {
//       res.statusCode = HTTPStatus.notFound;
//       res.writeBody(messageNotFound);
//       return;
//     }
// }
