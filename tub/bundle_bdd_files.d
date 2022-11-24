#!/usr/bin/env rdmd
import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.stdio;
import std.process;
import core.stdc.string : strlen;
import std.conv : to;
import std.string;

auto get_md_files(string pathname)
{    

    return dirEntries(pathname, SpanMode.depth)
        .filter!(f => f.name.endsWith(".md"))
        .filter!(f => f.name.canFind("gen.md"))
        .array;
    
}

int main(string[] args) {
    // const BDD = environment["BDD"];
    const BDD_PATH = "/home/imrying/work/tagion/bdd";
    const BDD_LENGTH = BDD_PATH.length;

    auto md_files = get_md_files(BDD_PATH);

    string[] paths;
    foreach(i, file; md_files) {
        paths ~= toStringz(file[BDD_LENGTH-3 .. file.length]).to!string;
    }

    writeln(paths);
    return 0;

}