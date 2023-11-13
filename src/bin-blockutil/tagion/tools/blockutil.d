//\blockfile.d database blockfile tool
module tagion.tools.blockutil;

import std.algorithm;
import std.array : join;
import std.conv : to;
import std.exception;
import std.format;
import std.getopt;
import std.range;
import std.stdio;
import std.traits : EnumMembers;
import tagion.dart.BlockFile;
import tagion.dart.DARTException : BlockFileException;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.tools.Basic;
import tagion.tools.revision;
import tools = tagion.tools.toolsexception;

mixin Main!_main;

enum HAS_BLOCK_FILE_ARG = 2;

enum ExitCode {
    NOERROR,
    MISSING_BLOCKFILE, /// Blockfile missing argument
    BAD_BLOCKFILE, /// Bad blockfile format
    OPEN_FILE_FAILED, /// Unable to open file
}

@safe
struct BlockFileAnalyzer {
    private BlockFile blockfile;
    uint inspect_iterations = uint.max;
    uint max_block_iteration = 1000;
    Index index_from;
    Index index_to;
    ~this() {
        if (blockfile) {
            blockfile.close;
        }
    }

    void print() {
        writeln("Block map");
        blockfile.dump(from : index_from, to:
                index_to);
    }

    void recyclePrint() {
        writeln("Recycler map");
        blockfile.recycleDump;
    }

    void recycleStatisticPrint() {
        blockfile.recycleStatisticDump;
    }

    void printStatistic() {
        blockfile.statisticDump;
    }

    void dumpGraph() {
        import std.algorithm;
        import std.range;

        auto text = [
            "```graphviz",
            "digraph {",
            `e [shape=record label="{`,
        ];

        BlockFile.BlockSegmentRange seg_range = blockfile[index_from .. index_to];
        const uint segments_per_line = 16;
        uint pos = 0;
        string[] line = ["{"];

        foreach (seg; seg_range) {

            if (pos == segments_per_line) {
                scope (exit) {
                    line = ["{"];
                    pos = 0;
                }
                line ~= "}|";
                text ~= line.join;
                // go to the next
            }

            string repeat_char;
            if (seg.type.length == 0) {
                repeat_char = "A";
            }
            else {
                repeat_char = seg.type[0 .. 1];
            }

            line ~= repeat(repeat_char, seg.size).array.join;
            line ~= ["|"];

            pos += 1;
        }
        if (seg_range.walkLength % segments_per_line != 0) {
            line ~= "}|";
            text ~= line.join;
        }

        text ~= `}"]`;
        text ~= "}";
        text ~= "```";
        // add the end
        text.each!writeln;
    }

    const(Document) dumpIndexDoc(const(Index) index) {
        return blockfile.load(index);
    }

    void printHeader() {
        writefln("%s", blockfile.headerBlock);
    }

    void printMaster() {
        writefln("%s", blockfile.masterBlock);
    }
}

BlockFileAnalyzer analyzer;
int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool display_meta;
    bool print; /// prints the block map
    bool inspect;
    bool ignore; /// Ignore blockfile format errors
    ulong block_number; /// Block number to read (block_number > 0)
    bool sequency; /// Prints the sequency on the next header
    bool print_recycler;
    bool print_recycler_statistic;
    bool print_statistic;
    bool print_graph;
    bool dump_doc;
    bool print_header;
    bool print_master;
    ulong[] indices;
    bool dump;
    string index_range;
    string output_filename;
    enum logo = import("logo.txt");
    string filename;
    try {

        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "Display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "R|range", "Sets range of block indices (Default is full range)", &index_range,
                "print", "Prints the entire blockfile", &print,
                "print-recycler", "Dumps the recycler", &print_recycler,
                "r|recyclerstatistic", "Dumps the recycler statistic block", &print_recycler_statistic,
                "s|statistic", "Dumps the statistic block", &print_statistic,
                "g|print-graph", "Dump the blockfile in graphviz format", &print_graph,
                "d|dumpdoc", "Dump the document located at an specific index", &dump_doc,
                "H|header", "Dump the header block", &print_header,
                "M|master", "Dump the master block", &print_master,
                "i|index", "the index to dump the document from", &indices,
                "o|output", "Output filename (Default stdout)", &output_filename,
                "dump", "Dumps the blocks as a HiBON sequency to stdout or a file", &dump,

        );

        if (version_switch) {
            revision_text.writeln;
            return ExitCode.NOERROR;
        }

        if (main_args.helpWanted) {
            writeln(logo);
            defaultGetoptPrinter(
                    [
                    revision_text,
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
            return ExitCode.NOERROR;
        }

        if (args.length !is HAS_BLOCK_FILE_ARG) {
            error("Missing blockfile");
            return ExitCode.MISSING_BLOCKFILE;
        }

        if (dump) {
            vout = stderr;
        }
        filename = args[1]; /// First argument is the blockfile name
        analyzer.blockfile = BlockFile(filename);
        size_t index_from, index_to;
        if (!index_range.empty) {
            const fields =
                index_range.formattedRead("%d:%d", index_from, index_to)
                    .ifThrown(0);
            tools.check(fields == 2,
                    format("Angle range shoud be ex. --range 42:117 not %s", index_range));
            verbose("Angle from [%d:%d]", index_from, index_to);
            analyzer.index_from = index_from;
            analyzer.index_to = index_to;
            //return 0;

        }

        if (dump) {
            File fout = stdout;
            if (!output_filename.empty) {
                fout = File(output_filename, "w");
            }
            scope (exit) {
                if (fout !is stdout) {
                    fout.close;
                }
            }
            foreach (block_segment; analyzer.blockfile[index_from .. index_to]) {
                fout.rawWrite(block_segment.doc.serialize);
            }
            return 0;
        }
        if (print) {
            analyzer.print;
        }

        if (print_header) {
            analyzer.printHeader;
        }
        if (print_master) {
            analyzer.printMaster;
        }

        if (print_recycler) {
            analyzer.recyclePrint;
        }

        if (print_recycler_statistic) {
            analyzer.recycleStatisticPrint;
        }

        if (print_statistic) {
            analyzer.printStatistic;
        }

        if (print_graph) {
            analyzer.dumpGraph;
        }

        if (!indices.empty) {
            File fout = stdout;
            if (!output_filename.empty) {
                fout = File(output_filename, "w");
            }
            scope (exit) {
                if (fout !is stdout) {
                    fout.close;
                }
            }
            foreach (index; indices) {
                const doc = analyzer.dumpIndexDoc(Index(index));
                fout.rawWrite(doc.serialize);
            }
        }
    }
    catch (BlockFileException e) {
        stderr.writefln("Error: Bad blockfile format for %s", filename);
        error(e);
        stderr.writefln(
                "Try to use the --inspect or --ignore switch to analyze the blockfile format");
        return ExitCode.BAD_BLOCKFILE;
    }
    catch (Exception e) {
        stderr.writefln("Error: Unable to open file %s", filename);
        error(e);
        return ExitCode.OPEN_FILE_FAILED;
    }

    return ExitCode.NOERROR;
}
