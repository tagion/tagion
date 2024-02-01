module tagion.tools.vergangenheit.vergangenheit;
import std.array : join;
import std.getopt;
import std.stdio;
import std.format;
import std.algorithm;

import tagion.basic.Types;
import tagion.tools.Basic;
import tagion.tools.revision;
import tools = tagion.tools.toolsexception;

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    GetoptResult main_args;
    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch,
    /*
        "c|stdout", "Print to standard output", &standard_output,
                "s|stream", "Parse .hibon file to stdout", &stream_output,
                "o|output", "Output filename only for stdin data", &outputfilename,
                "r|reserved", "Check reserved keys and types enabled", &reserved,
                "p|pretty", format("JSON Pretty print: Default: %s", pretty), &pretty,
                "J", "Input stream format json", &input_json,
                "t|base64", "Convert to base64 output", &output_base64,
                "x|hex", "Convert to hex output", &output_hex,
                "T|text", "Input stream base64 or hex-string", &input_text,
                "sample", "Produce a sample HiBON", &sample,
                "check", "Check the hibon format", &hibon_check,
                "H|hash", "Prints the hash value", &output_hash,
                "D|dartindex", "Prints the DART index", &output_dartindex,
                "ignore", "Ignore document valid check", &ignore,
    */  
    );
        if (version_switch) {
            revision_text.writeln;
            return 0;
        }

        if (main_args.helpWanted) {
//            writeln(logo);
            defaultGetoptPrinter(
                    [
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] <in-file>", program),
                "",
                "Where:",
                "<in-file>           Is an input file in .json or .hibon format",
                "",

                "<option>:",

            ].join("\n"),
                    main_args.options);
            return 0;
        }
        const net=new StdHashNet;
        auto dart_list=args.filter!(file => file.hasExtension(FileExtension.dart));
        tools.check(!dart_list.empty, format("Missing %s file", FileExtension.dart));
        auto db_src=DART(net, dart_list.front, Yes.read_only);
        
        dart_file.popFront;
        tools.check(!dart_list.empty, "DART destination file missing");
        auto db_dst=DART(dart_list.front);
        scope(exit) {
            db_src.close;
            db_dst.close;
        }
        
    }
    catch (Exception e) {
        error(e);

        return 1;
    }
    return 0;
 
    return 0;
}
