module services.fsService;

import std.stdio;
import std.file;
import std.algorithm;
import std.conv;
import vibe.data.json;

public void writeToFile(Json[] entityList, string filePath) {
    import std.file : write;

    File file = File(filePath, "w");
    file.writeln(entityList);
    file.close();
}

public Json[] readFromFile(string filePath) {
    import std.file : readText;

    // if file does not exist, create file with empty array
    if (!exists(filePath)) {
        File file = File(filePath, "w");
        file.writeln("[]");
        file.close();
    }

    string data = readText(filePath) ? readText(filePath) : "[]";

    Json jsonData = parseJson(data);

    Json[] jsonArray = cast(Json[]) jsonData;

    return jsonArray;
}
