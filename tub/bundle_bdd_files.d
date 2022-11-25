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
    return dirEntries(pathname, SpanMode.depth)
        .filter!(f => f.name.endsWith("gen.md"))
        .array;
}

int main(string[] args) {
    // const BDD = environment["BDD"];
    //const BDD_PATH = "/home/imrying/work/tagion/bdd";
    const BDD = environment["BDD"];
    const REPOROOT = environment["REPOROOT"];
    const FILE = "/home/imrying/work/tagion/test.md";

    auto md_files = get_md_paths(BDD);

    string[] relative_paths;
    foreach(i, file; md_files) {
        relative_paths ~= relativePath(file, REPOROOT);
    }

    auto fout = File(FILE, "w");


    foreach(i, path; relative_paths) {
        fout.writefln("[%s](%s)", path.baseName, path);
        fout.writeln("");
    }
    fout.close();


    return 0;

}