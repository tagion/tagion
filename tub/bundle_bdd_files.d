#!/usr/bin/env rdmd
import std.algorithm;
import std.array;
import std.conv : to;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;

auto get_md_paths(string pathname) {
    return dirEntries(buildPath(pathname, "tagion"), SpanMode.depth)
        .filter!(f => f.name.endsWith(".md"))
        .filter!(f => !f.name.endsWith(".gen.md"))
        .array;
}

int main(string[] args) {

    const BDD = environment["BDD"];
    const REPOROOT = environment["REPOROOT"];
    //const FILE = buildPath(BDD, "BDDS.md");
    const FILE = args[1];
    auto md_files = get_md_paths(BDD).sort;

    string[] relative_paths;
    foreach (file; md_files) {
        relative_paths ~= relativePath(file, REPOROOT);
    }

    auto fout = File(FILE, "w");
    scope (exit) {
        fout.close;
    }

    foreach (path; relative_paths) {
        fout.writefln("[%s](%s)", path.baseName, path);
        fout.writeln("");
    }

    return 0;
}
