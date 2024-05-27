/// HiRPC utility for generating HiRPC requests
module tagion.tools.hirpc;


import tagion.tools.Basic;
import tagion.tools.revision;
import tools = tagion.tools.toolsexception;
import tagion.basic.Types : FileExtension, hasExtension;
import tagion.services.DARTInterface : all_dartinterface_methods, accepted_dart_methods, accepted_trt_methods;
import tagion.dart.DARTBasic;
import tagion.dart.DARTcrud;
import tagion.tools.dartutil.dartindex;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.hibon.Document;
import tagion.script.standardnames;
import tagion.hibon.HiBONtoText : decode;

import std.path;
import std.stdio;
import std.getopt;
import std.format;
import std.array;
import std.algorithm;




mixin Main!_main;
int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    string output_filename;
    string method_name;
    string input;
    bool pkey;

    try {
        auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "v|verbose", "Prints more debug information", &__verbose_switch,
            "o|output", "Output filename (Default stdout)", &output_filename,
            "m|method", "method name for the hirpc to generate", &method_name,
            "i|input", "inputs sep. by comma for multiples generated differently for each cmd", &input,
            "pkey", "trtpubkey lookup", &pkey,
        );

        if (version_switch) {
            revision_text.writeln;
            return 0;
        }

        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                [
                "Documentation: https://docs.tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...]", program),
                "",
                "<option>:",

            ].join("\n"),
            main_args.options);
            return 0;
        }

        tools.check(method_name !is string.init, "must supply methodname");

        File fout;
        if (output_filename is string.init) {
            fout = stdout;
        }
        else {
            tools.check(output_filename.hasExtension(FileExtension.hibon),
                format("Output %s should be a .%s file", output_filename, FileExtension.hibon));
            fout = File(output_filename, "w");
        }

        tools.check(all_dartinterface_methods.canFind(method_name), format("method name not valid must be one of %s", all_dartinterface_methods));

        writeln(method_name);

        DARTIndex[] get_indices(string _input) {
            return _input
                .split(",")
                .array
                .map!(d => hash_net.dartIndexDecode(d))
                .array;
        }

        DARTIndex[] get_pkey_indices(string _input) {
            return _input
                .split(",")
                .array
                .map!(p => hash_net.dartKey(TRTLabel, Pubkey(p.decode)))
                .array;
        }

        enum TRT_METHOD = "trt.";
        bool isTRTreq() {
            return method_name.startsWith(TRT_METHOD);
        }

        Document result;
        switch(method_name) {
            case Queries.dartBullseye:
                result = dartBullseye().toDoc;
                break;
            case Queries.dartRead, TRT_METHOD ~ Queries.dartRead:
                tools.check(input !is string.init, format("must supply input for %s", method_name));
                const dart_indices = pkey ? get_pkey_indices(input) : get_indices(input);
                result = isTRTreq ? trtdartRead(dart_indices).toDoc : dartRead(dart_indices).toDoc;
                break;
            case Queries.dartCheckRead, TRT_METHOD ~ Queries.dartCheckRead:
                tools.check(input !is string.init, format("must supply input for %s", method_name));
                const dart_indices = pkey ? get_pkey_indices(input) : get_indices(input);
                result = isTRTreq ? trtdartCheckRead(dart_indices).toDoc : dartCheckRead(dart_indices).toDoc;
                break;
            default:
                tools.check(0, format("method %s not currently implemented", method_name));
        }
        fout.rawWrite(result.serialize);
    }
    catch (Exception e) {
        error(e);
        return 1;

    }

    return 0;
}
