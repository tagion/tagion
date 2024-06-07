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

static immutable IMPLEMENTED_METHODS = [
    Queries.dartRead,
    Queries.dartCheckRead,
    Queries.dartBullseye,
];

mixin Main!_main;
int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    string output_filename;
    string method_name;
    string input;
    string pkeys;

    try {
        auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "v|verbose", "Prints more debug information", &__verbose_switch,
            "o|output", "Output filename (Default stdout)", &output_filename,
            "m|method", "method name for the hirpc to generate", &method_name,
            "d|dartinput", "dart inputs sep. by comma for multiples generated differently for each cmd", &input,
            "p|pkeys", "pkeys sep. by comma for multiple entries", &pkeys,
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
            case Queries.dartBullseye, TRT_METHOD ~ Queries.dartBullseye:
                result = isTRTreq ? trtdartBullseye().toDoc : dartBullseye().toDoc;
                break;
            case Queries.dartRead, TRT_METHOD ~ Queries.dartRead:
                tools.check(input !is string.init || pkeys !is string.init, "must supply pkeys or dartindices"); 
                const dart_indices = get_indices(input);
                const pkey_indices = get_pkey_indices(pkeys);
                const res = dart_indices ~ pkey_indices;
                result = isTRTreq ? trtdartRead(res).toDoc : dartRead(res).toDoc;
                break;
            case Queries.dartCheckRead, TRT_METHOD ~ Queries.dartCheckRead:
                tools.check(input !is string.init || pkeys !is string.init, "must supply pkeys or dartindices"); 
                const dart_indices = get_indices(input);
                const pkey_indices = get_pkey_indices(pkeys);
                const res = dart_indices ~ pkey_indices;
                result = isTRTreq ? trtdartCheckRead(res).toDoc : dartCheckRead(res).toDoc;
                break;
            default:
                tools.check(0, format("method %s not implemented use one of %s", method_name, IMPLEMENTED_METHODS));
        }
        fout.rawWrite(result.serialize);
    }
    catch (Exception e) {
        error(e);
        return 1;

    }

    return 0;
}
