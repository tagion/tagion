#!/usr/bin/env rdmd

import std.stdio;
import std.file : dirEntries, readText, exists, mkdirRecurse, rmdir;
import std.path;
import std.process;


string[] listdir(string pathname)
{
    import std.algorithm;
    import std.array;
    import std.file;
    import std.path;

    
    foreach(file; dirEntries(pathname, SpanMode.shallow)
        .filter!(a => a.isFile)) {
            writefln("file: %s", file);
        }

}

int main(string[] args) {
    const BDD = environment["BDD"];
    
    return 0;

}