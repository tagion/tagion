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

import services.routerService;
import services.fsService;

import routes.project.model;

public Json[] projectList;
public string filePath = "./source/routes/project/data.json";

void getAllProjects(HTTPServerRequest req, HTTPServerResponse res) {
    getAll(req, res, projectList, filePath);
}

void getOneProject(HTTPServerRequest req, HTTPServerResponse res) {
    getOne(req, res, projectList, filePath, "projectUUID");
}

void postProject(HTTPServerRequest req, HTTPServerResponse res) {
    struct PostResponse {
      string id;
    }

    // check that user submits correct body
    try {
        deserializeJson!Project(req.json);
    } catch (Exception e) {
        res.statusCode = HTTPStatus.badRequest;
        res.writeBody("Request body does not match JSON struct");
        return;
    }

    projectList = readFromFile(filePath);

    // throw error if object with provided ID already exists
    if (projectList.length > 0) {
      foreach(key, value; projectList) {
        if (value["projectUUID"] == req.json["projectUUID"]) {
          res.writeBody("Object with this ID exists");
          return;
        }
      }
    }

    projectList ~= req.json;

    writeToFile(projectList, filePath);

    // TODO: return GUID representing data entry in DART db
    PostResponse postResponse;
    postResponse.id = "d76sc703-9334-46d1-93c9-5675656c0000";
    
    res.statusCode = HTTPStatus.created;
    res.writeJsonBody(postResponse);
}

void deleteOneProject(HTTPServerRequest req, HTTPServerResponse res) {
    deleteOne(req, res, projectList, filePath, "projectUUID");
}