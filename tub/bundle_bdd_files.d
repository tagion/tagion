#!/usr/bin/env rdmd
import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.stdio;
import std.process;
import std.conv : to;
import std.string;

auto get_md_paths(string pathname)
{    
    return dirEntries(buildPath(pathname, "tagion"), SpanMode.depth)
        .filter!(f => f.name.endsWith(".md"))
        .filter!(f => !f.name.endsWith(".gen.md"))
        .array;
}

int main(string[] args) {

    const BDD = environment["BDD"];
    const REPOROOT = environment["REPOROOT"];
    const FILE = buildPath(BDD, "BDDS.md");

    auto md_files = get_md_paths(BDD);

    string[] relative_paths;
    foreach(i, file; md_files) {
        writeln(file);
        writeln(REPOROOT);
        relative_paths ~= relativePath(file, BDD);
    }

    auto fout = File(FILE, "w");


    foreach(i, path; relative_paths) {
        fout.writefln("[%s](%s)", path.baseName, path);
        fout.writeln("");
    }
    fout.close();


    return 0;

}