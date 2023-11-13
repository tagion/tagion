module tagion.tools.hirep.hirep;

import std.array;
import std.file : exists;
import std.format;
import std.getopt;
import std.path;
import std.range;
import std.stdio;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.basic.tagionexceptions;
import tagion.crypto.SecureNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONFile : HiBONRange;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.hibon.HiBONregex : HiBONregex;
import tagion.tools.Basic;
import tagion.tools.boot.genesis;
import tagion.tools.revision;
import tagion.utils.Term;

alias check = Check!TagionException;

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool standard_output;
    bool standard_input;
    bool not_flag;
    string output_filename;
    string name;
    string record_type;
    string[] types;
    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch, //        "invoice|i","Sets the HiBON input file name", &invoicefile,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "c|stdout", "Print to standard output", &standard_output,
                "n|name", "HiBON member name (name as text or regex as `regex`)", &name,
                "r|recordtype", "HiBON recordtype (name as text or regex as `regex`)", &record_type,
                "t|type", "HiBON data types", &types,
                "not", "Filter out match", &not_flag, //               "o|output", format("Output filename : Default %s", output_filename), &output_filename, // //        "output_filename|o", format("Sets the output file name: default : %s", output_filenamename), &output_filenamename,
                //                "p|nodekey", "Node channel key(Pubkey) ", &nodekeys, //         "bills|b", "Generate bills", &number_of_bills,
                // "value|V", format("Bill value : default: %d", value), &value,
                // "passphrase|P", format("Passphrase of the keypair : default: %s", passphrase), &passphrase
                //"initbills|b", "Testing mode", &initbills,
                //"nnc", "Initialize NetworkNameCard with given name", &nnc_name,

                

        );

        if (version_switch) {
            revision_text.writeln;
            return 0;
        }

        if (main_args.helpWanted) {
            //       writeln(logo);
            defaultGetoptPrinter(
                    [
                    //                format("%s version %s", program, REVNO),
                    "Documentation: https://tagion.org/",
                    "",
                    "Usage:",
                    format("%s [<option>...] <hibon-files> ...", program),
                    "",
                    "Where:",
                    format("<file>           hibon outfile (Default %s)", output_filename),
                    "",

                    "<option>:",

                    ].join("\n"),
                    main_args.options);
            return 0;
        }

        if (name) {
            writefln("%s", name);
            writefln("%s", record_type);
            writefln("%s", types);
        }
        HiBONregex hibon_regex;
        if (name) {
            hibon_regex.name = name;
        }
        if (record_type) {
            hibon_regex.record_type = record_type;
        }
        if (args.length == 1) {
            File fin;
            fin = stdin;
            File fout;
            fout = stdout;
            foreach (no, doc; HiBONRange(fin).enumerate) {
                if (hibon_regex.match(doc)) {
                    verbose("%d\n%s", no, doc.toPretty);
                    fout.rawWrite(doc.serialize);
                }
            }
        }
    }
    catch (Exception e) {
        error(e);
        return 1;

    }
    return 0;
}
