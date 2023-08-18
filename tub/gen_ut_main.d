#!/usr/bin/env rdmd
/// Run from tagion-core reporoot
import std.stdio;
import std.file;

void main() {
    foreach(string f; dirEntries("../src/", SpanMode.shallow))
        writeln(f);
}
