module tagion.tools.devutils;

import std.stdio;
import std.typetuple;
import std.traits;
import std.array;
import std.range;
import std.algorithm : remove;

import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {
    enum tailName(string name) = name.split(".").tail(1)[0];
    enum toolName(alias tool) = tailName!(moduleName!tool);

    import dartstat = tagion.devutils.dartstat;

    alias allutils = AliasSeq!(
            dartstat,
    );

    if (args.length < 2) {
        stderr.writeln("Need a tool name:");
        stderr.writefln("%-(\t%s\n%)", [staticArray!(toolName!allutils)]);
        return 1;
    }
    const util = args[1];
    auto utilargs = args.remove(0);

    switch (util) {
        static foreach (utilname; allutils) {
    case toolName!utilname:
            return utilname._main(utilargs);
        }
    default:
        stderr.writefln("Unknown tool %s", util);
        return 1;
    }
}
