module tagion.tools.blockfile;

import std.getopt;
import std.stdio;
import std.format;
import std.array : join;
import std.traits : EnumMembers;
import std.conv : to;
//import std.file : toFile;

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


    string blockType(const uint index) {
        return blockfile.isRecyclable(index)?"Recycle":"Data";
    }

    void display_block(const uint index, const(BlockFile.Block) b) {
        if (b) {
            writefln("%s  [%d <- %d -> %d size %d [%s]", (b.head)?"H":"#", b.previous, index, b.next, b.size, blockType(index));
            return;
        }
        writefln("Block @ %d is nil", index);
    }

    bool trace(const uint index, const BlockFile.Fail f, scope const BlockFile.Block block, const bool data_flag) {
        void error(string msg, const uint i=index, const bool flag=data_flag) {
            writefln("Error %s: %s @ %d in %s", f, msg, i, (flag)?"Data":"Recycle");
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
                    while (!range.empty && index !is range.index);
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
                    error(format("Size of end-block is larger then %d", blockfile.DATA_SIZE), block.previous, true);
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
        foreach(symbol; EnumMembers!(BlockFile.BlockSymbol)) {
            writef("'%s' %s, ", symbol.to!char, symbol);
        }
        writeln;
        blockfile.dump;
    }

    /**
       number_of_seq block sequency displays
     */
    void display_sequency(const uint index, uint number_of_sequency = 1) {
        auto range = blockfile.range(index);
        while(!range.empty) {
            display_block(range.index, range.front);
            range.popFront;
            if (range.front !is null && range.front.head) {
                number_of_sequency--;
                if (number_of_sequency == 0) {
                    return;
                }
                writeln;
            }
        }
    }

}


BlockFileAnalyzer analyzer;
int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool display_meta;
    bool dump; /// Dumps the block map
    bool inspect;
    bool ignore; /// Ignore blockfile format errors
    uint block_number; /// Block number to read (block_number > 0)
    bool sequency; /// Prints the sequency on the next header
    string output_filename;
    enum logo = import("logo.txt");
//    auto result = ExitCode.noerror;
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
        "ignore|i", "Ignore blockfile format error", &ignore,
        "iter", "Set the max number of iterations do by the inspect", &analyzer.inspect_iterations,
        "max", format("Max block iteration Default : %d", analyzer.max_block_iteration), &analyzer.max_block_iteration,
        "block|b", "Read from block number", &block_number,
        "seq", "Display the block sequency starting from the block-number", &sequency,
        "o", "Output filename", &output_filename,
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

    if (inspect || ignore) {
        //analyzer.inspect(filename);
        //void inspect(string filename) {
        if (!analyzer.blockfile) {
            analyzer.blockfile = BlockFile.Inspect(filename, &report, analyzer.max_block_iteration);
        }
        if (inspect) {
            analyzer.blockfile.inspect(&analyzer.trace);
        }
    }
    else {
    try {
        analyzer.blockfile = BlockFile(filename);
    }
    catch (BlockFileException e) {
        stderr.writefln("Error: Bad blockfile format for %s", filename);
        stderr.writeln(e.msg);
        stderr.writefln("Try to use the --inspect or --ignore switch to analyze the blockfile format");
        return ExitCode.bad_blockfile;
        // display_meta = true;
        // dump = true;
    }
    catch (Exception e) {
        stderr.writefln("Error: Unable to open file %s", filename);
        stderr.writeln(e.msg);
        return ExitCode.open_file_failed;
    }
    }
        if (display_meta) {
            analyzer.display_meta;
        }

        if (dump) {
            analyzer.dump;
        }

        if (block_number !is 0) {
            if (sequency) {
                analyzer.display_sequency(block_number);
            }
            else {
            immutable buffer = analyzer.blockfile.load(block_number, !ignore);
            if (output_filename) {
                buffer.toFile(output_filename);
            }
            }
        }

    return ExitCode.noerror;
}
