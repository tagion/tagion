module tagion.tools.blockfile;

import std.getopt;
import std.stdio;
import std.format;
import std.array : join;

import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.dart.BlockFile;
import tagion.dart.DARTException : BlockFileException;

mixin Main!(_main, "blockutil");

enum HAS_BLOCK_FILE_ARG = 2;

enum ExitCode {
    noerror,
    missing_blockfile, /// Blockfile missing argument
    bad_blockfile,     /// Bad blockfile format
    open_file_failed,    /// Unable to open file
}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool display_meta;
    bool dump;
    uint inspect_iterations =uint.max;
    bool inspect;
    enum logo = import("logo.txt");
    auto result = ExitCode.noerror;


    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version", "Display the version", &version_switch,
        "info", "Display blockfile metadata", &display_meta,
        "dump", "Dumps block fragmentaion pattern in the blockfile", &dump,
        "inspect|c", "Inspect the blockfile format", &inspect,
        "iter", "Set the max number of iterations do by the inspect", &inspect_iterations,

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
    BlockFile blockfile;
    scope (exit)
    {
        if (blockfile) {
            blockfile.close;
        }
    }

    if (inspect) {
        if (!blockfile) {
            string msg;
            blockfile = BlockFile.Inspect(filename, msg);
            stderr.writeln(msg);
        }
        bool trace(const uint index, const BlockFile.Fail f, const BlockFile.Block block, const bool data_flag) {
            writefln("@ %d %s %s", index, f, data_flag);
            if (inspect_iterations != inspect_iterations.max) {
                inspect_iterations --;
                return inspect_iterations == 0;
            }
            return false;
        }
        blockfile.inspect(&trace);
    }
    else {
    try {
        blockfile = BlockFile(filename);
    }
    catch (BlockFileException e) {
        stderr.writefln("Error: Bad blockfile format for %s", filename);
        stderr.writeln(e.msg);
        result = ExitCode.bad_blockfile;
        display_meta = true;
        dump = true;
    }
    catch (Exception e) {
        stderr.writefln("Error: Unable to open file %s", filename);
        stderr.writeln(e.msg);
        result = ExitCode.open_file_failed;
    }
    }

    if (display_meta) {
        blockfile.headerBlock.writeln;
        writeln;
        blockfile.masterBlock.writeln;
        writeln;
        writefln("Last block @ %d", blockfile.lastBlockIndex);
        writeln;
    }

    if (dump) {
        writeln("Block map");
        writeln("H Header, # Used, _ Recycle");

        blockfile.dump;
    }

    return result;
}
