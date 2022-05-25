#!/usr/bin/rdmd -g

import std.ascii : isAlphaNum;
import std.algorithm.iteration : chunkBy, joiner, map, each;
import std.algorithm.mutation : copy;
import std.conv : to;
import std.demangle : demangle;
import std.functional : pipe;
import std.stdio : stdin, stdout, File, writefln, writeln;
import std.file : exists;
import std.range : zip;
import std.array : join;
import std.getopt;
import std.format;

int main(string[] args) {
    bool mangle_split;
    bool version_switch;
    immutable program = "dmangle";
    auto main_args = getopt(
            args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "split|s", "Split both mange and demangle", &mangle_split,
    );
    if (version_switch) {
        import std.process;
        return 0;
    }

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
            // format("%s version %s", program, REVNO),
            "Documentation: https://tagion.org/",
            "",
            "Usage:",
            format("%s [<option>...] <in-file> <out-file>", program),
            format("%s [<option>...] # for stdin", program),
            "",
            "Where:",
            "<in-file>           Is an input file of dmangles",
            "",

            "<option>:",

        ].join("\n"),
        main_args.options);
        return 0;
    }

    File fin;
    if (args.length == 1) {
        fin = stdin;
    }
    else if (args.length == 2) {
        if (args[1] == "-h") {
            writefln("%s [file|demangles]", program);
            return 0;
        }
        else if (args[1].exists) {
            fin = File(args[1], "r");
        }
    }
    if (fin is File.init) {
        foreach (arg; args[1 .. $]) {
            writeln;
            writefln("%s", arg);
            writefln("%s", arg.demangle);
        }
    }
    else {
        auto filter_mangle = fin
            .byLineCopy
            .map!(
                    l => l.chunkBy!(a => isAlphaNum(a) || a == '_')
                    .map!(a => a[1].pipe!(to!string, demangle))
                    .joiner
            );
        if (mangle_split) {
            zip(fin.byLine, filter_mangle)
                .each!(a => writefln("%s\n%s\n", a[0], a[1]));
        }
        else {
            filter_mangle
                .each!writeln;
        }
    }
    return 0;
}
