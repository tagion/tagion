module tagion.tools.hibonutil;

import std.getopt;
import std.stdio;
import std.file : fread = read, fwrite = write, exists, readText;
import std.format;
import std.path : extension, withExtension;
import std.traits : EnumMembers;
import std.exception : assumeUnique, assumeWontThrow;
import std.json;
import std.range : only;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.Types : Buffer, Pubkey, FileExtension;
import tagion.basic.Basic : basename, fileExtension;
import tagion.hibon.HiBONJSON;

//import tagion.script.StandardRecords;
import std.array : join;

// import tagion.revision;

// enum fileextensions {
//     HIBON = ".hibon",
//     JSON = ".json"
// };

import tagion.tools.Basic;

mixin Main!_main;

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;

    string inputfilename;
    string outputfilename;
    //    StandardBill bill;
    bool binary;

    //    string passphrase="verysecret";
    ulong value = 1000_000_000;
    bool pretty;

    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "inputfile|i", "Sets the HiBON input file name", &inputfilename,
            "outputfile|o", "Sets the output file name", &outputfilename,
            "bin|b", "Use HiBON or else use JSON", &binary,
            "value|V", format("Bill value : default: %d", value), &value,
            "pretty|p", format("JSON Pretty print: Default: %s", pretty), &pretty,
    );

    if (version_switch) {
        // writefln("version %s", REVNO);
        // writefln("Git handle %s", HASH);
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
            format("%s [<option>...] <in-file>", program),
            "",
            "Where:",
            "<in-file>           Is an input file in .json or .hibon format",
            "<out-file>          Is an output file in .json or .hibon format",
            "                    stdout is used of the output is not specifed the",
            "",

            "<option>:",

        ].join("\n"),
        main_args.options);
        return 0;
    }
    //    writefln("args=%s", args);
    if (args.length > 3) {
        stderr.writefln("Only one output file name allowed (given %s)", args[1 .. $]);
        return 3;
    }
    if (args.length > 2) {
        outputfilename = args[2];
        //        writefln("outputfilename%s", outputfilename);
    }
    if (args.length > 1) {
        inputfilename = args[1];
    }
    else {
        stderr.writefln("Input file missing");
        return 1;
    }

    immutable standard_output = (outputfilename.length == 0);
    //    auto input_extension=inputfilename.extension;
    //    string output_extension;
    // if (standard_output) {
    //     output_extension=outputfilename.extension;
    // }
//    const input_extension = inputfilename.extension;
    //   writefln("input_extension=%s", input_extension);
    switch (inputfilename.fileExtension) {
    case FileExtension.hibon:
        immutable data = assumeUnique(cast(ubyte[]) fread(inputfilename));
        const doc = Document(data);
        const error_code = doc.valid(
                (
                const(Document) sub_doc,
                const Document.Element.ErrorCode error_code,
                const(Document.Element) current, const(
                Document.Element) previous) nothrow{ assumeWontThrow(writefln("%s", current)); return true; });
        if (error_code !is Document.Element.ErrorCode.NONE) {
            writefln("Errorcode %s", error_code);
            return 1;
        }
        auto json = doc.toJSON;
        auto json_stringify = (pretty) ? json.toPrettyString : json.toString;
        if (standard_output) {
            writefln("%s", json_stringify);
        }
        else {
            outputfilename.fwrite(json_stringify);
        }
        break;
    case FileExtension.json:
        const data = inputfilename.readText;
        auto parse = data.parseJSON;
        auto hibon = parse.toHiBON;
        if (standard_output) {
            write(hibon.serialize);
        }
        else {
            outputfilename.fwrite(hibon.serialize);
        }
        break;
    default:
        stderr.writefln("File %s not valid (only %(.%s %))",
            inputfilename, only(FileExtension.hibon, FileExtension.json));
        return 1;
    }

    return 0;
}
