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

@safe
struct BlockFileAnalyzer {
    private BlockFile blockfile;
    uint inspect_iterations =uint.max;
    uint max_block_iteration = 1000;
    // void report(string msg) {
    //     writefln("Error: %s", msg);
    // }

    ~this() {
        if (blockfile) {
            blockfile.close;
        }
    }

    // void inspect(string filename) {
    //     if (!blockfile) {
    //         this.blockfile = BlockFile.Inspect(filename,
    //             &report,
    //             max_block_iteration);
    //     }
    // }

    static void display_block(const uint index, const(BlockFile.Block) b) {
        writefln("%s  [%d <- %d -> %d size %d", (b.head)?"H":"#", b.previous, index, b.next, b.size);
    }

    bool trace(const uint index, const BlockFile.Fail f, scope const BlockFile.Block block, const bool data_flag) {
        void error(string msg) {
            writefln("Error %s: %s @ %d in %s", f, msg, index, (data_flag)?"Recycle":"Data");
        }
        with(BlockFile.Fail) final switch(f) {
            case NON:
                // No error
                break;
            case RECURSIVE:
                error("Circular chain found");
                auto range = blockfile.range(index);
                    do {
                        display_block(range.index, range.front);
                        range.popFront;
                    }
                    while (index !is range.index);
                    return true;
                case INCREASING:
                    error("Block sequency order is wrong");
                    break;
                case SEQUENCY:
                    error("Chain of the block size is wrong");
                    break;
                case LINK:
                    error("Double linked fail");
                    break;
                case ZERO_SIZE:
                    error("Block has zero-size");
                    break;
                case BAD_SIZE:
                    error(format("Block size is larger then the data-size of %d", blockfile.DATA_SIZE));
                    break;
            }
                //writefln("@ %d %s %s", index, f, data_flag);
            if (inspect_iterations != inspect_iterations.max) {
                inspect_iterations --;
                return inspect_iterations == 0;
            }
            return false;
        }

    void display_meta() {
        blockfile.headerBlock.writeln;
        writeln;
        blockfile.masterBlock.writeln;
        writeln;
        writefln("Last block @ %d", blockfile.lastBlockIndex);
        writeln;
        blockfile.statistic.writeln;
        writeln;
    }

    void dump() {
        writeln("Block map");
        writeln("H Header, # Used, _ Recycle");
        blockfile.dump;
    }
}


BlockFileAnalyzer analyzer;
int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool display_meta;
    bool dump;
    bool inspect;
    enum logo = import("logo.txt");
    auto result = ExitCode.noerror;
    void report(string msg) {
        writefln("Error: %s", msg);
    }


    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version", "Display the version", &version_switch,
        "info", "Display blockfile metadata", &display_meta,
        "dump", "Dumps block fragmentaion pattern in the blockfile", &dump,
        "inspect|c", "Inspect the blockfile format", &inspect,
        "iter", "Set the max number of iterations do by the inspect", &analyzer.inspect_iterations,
        "max", format("Max block iteration Default : %d", analyzer.max_block_iteration), &analyzer.max_block_iteration,
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
    //    BlockFile blockfile;
    // scope (exit)
    // {
    //     if (analyzer.blockfile) {
    //         analyzer.blockfile.close;
    //     }
    // }

    if (inspect) {
        //analyzer.inspect(filename);
        //void inspect(string filename) {
        if (!analyzer.blockfile) {
            analyzer.blockfile = BlockFile.Inspect(filename, &report, analyzer.max_block_iteration);
        }
        analyzer.blockfile.inspect(&analyzer.trace);
//    }


        // void report(string msg) @trusted {
        //     stderr.writefln("Error: %s", msg);
        // }
        // if (!analyzer) {
        //     string msg;
        //     blockfile = BlockFile.Inspect(filename, &report, max_block_iteration);
        //     stderr.writeln(msg);
        // }
        // bool trace(const uint index, const BlockFile.Fail f, const BlockFile.Block block, const bool data_flag) {
        //     void error(string msg) {
        //         writefln("Error %s: %s @ %d in %s", f, msg, index, (data_flag)?"Recycle":"Data");
        //     }
        //     static void display_block(const uint index, const(BlockFile.Block) b) {
        //         writefln("%s  [%d <- %d -> %d size %d", (b.head)?"H":"#", b.previous, index, b.next, b.size);
        //     }
        //     with(BlockFile.Fail) final switch(f) {
        //         case NON:
        //             // No error
        //             break;
        //         case RECURSIVE:
        //             error("Circular chain found");
        //             auto range = blockfile.range(index);
        //             do {
        //                 display_block(range.index, range.front);
        //                 range.popFront;
        //             }
        //             while (index !is range.index);
        //             return true;
        //         case INCREASING:
        //             error("Block sequency order is wrong");
        //             break;
        //         case SEQUENCY:
        //             error("Chain of the block size is wrong");
        //             break;
        //         case LINK:
        //             error("Double linked fail");
        //             break;
        //         case ZERO_SIZE:
        //             error("Block has zero-size");
        //             break;
        //         case BAD_SIZE:
        //             error(format("Block size is larger then the data-size of %d", blockfile.DATA_SIZE));
        //             break;
        //     }
        //         //writefln("@ %d %s %s", index, f, data_flag);
        //     if (inspect_iterations != inspect_iterations.max) {
        //         inspect_iterations --;
        //         return inspect_iterations == 0;
        //     }
        //     return false;
        // }
        // blockfile.inspect(&trace);
    }
    else {
    try {
        analyzer.blockfile = BlockFile(filename);
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
        analyzer.display_meta;
        // blockfile.headerBlock.writeln;
        // writeln;
        // blockfile.masterBlock.writeln;
        // writeln;
        // writefln("Last block @ %d", blockfile.lastBlockIndex);
        // writeln;
        // blockfile.statistic.writeln;
        // writeln;
    }

    if (dump) {
        analyzer.dump;
    }

    return result;
}
