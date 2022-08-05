module tagion.tools.blockfile;

import std.getopt;
import std.stdio;
import std.format;
import std.array : join;

import tagion.tools.Basic;
import tagion.tools.revision;

mixin Main!(_main, "blockutil");

enum ExitCode {
    noerror,
}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    enum logo = import("logo.txt");


    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version", "display the version", &version_switch,
        );

    if (version_switch)
    {
        revision_text.writeln;
        return ExitCode.noerror;
    }

    if (main_args.helpWanted)
    {
        writeln(logo);
        defaultGetoptPrinter(
            [
            // format("%s version %s", program, REVNO),
            "Documentation: https://tagion.org/",
            "",
            "Usage:",
            format("%s <command> [<option>...]", program),
            "",
            "Where:",
            "<command>           one of [--read, --rim, --modify, --rpc]",
            "",

            "<option>:",

        ].join("\n"),
        main_args.options);
        return ExitCode.noerror;
    }


    return ExitCode.noerror;
}
