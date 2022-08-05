module tagion.tools.blockfile;

import std.getopt;
import std.stdio;
import std.format;
import std.array : join;

import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.dart.BlockFile;

mixin Main!(_main, "blockutil");

enum HAS_BLOCK_FILE_ARG = 2;

enum ExitCode {
    noerror,
    missing_blockfile, /// Blockfile missing
}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool display_meta;
    bool dump;
    enum logo = import("logo.txt");


    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version", "display the version", &version_switch,
        "info", "display blockfile metadata", &display_meta,
        "dump", "dump block in the blockfile", &dump,

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
            format("%s <file> [<option>...]", program),
            "",
            "Where:",
//            "<command>           one of [--read, --rim, --modify, --rpc]",
            "",

            "<option>:",

        ].join("\n"),
        main_args.options);
        return ExitCode.noerror;
    }

    if (args.length !is HAS_BLOCK_FILE_ARG) {
        stderr.writeln("Missing blockfile");
        return ExitCode.missing_blockfile;
    }

    immutable filename = args[1]; /// First argument is the blockfile name
    auto blockfile_load = BlockFile(filename);
    scope (exit)
    {
        blockfile_load.close;
    }

    if (display_meta) {
        blockfile_load.headerBlock.writeln;
        writeln;
        blockfile_load.masterBlock.writeln;
        writeln;
        writefln("Last block @ %d", blockfile_load.lastBlockIndex);
        writeln;
    }

    if (dump) {
        writeln("Block map");
        blockfile_load.dump;
    }

    return ExitCode.noerror;
}
