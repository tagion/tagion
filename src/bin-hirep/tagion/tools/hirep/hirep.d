module tagion.tools.hirep.hirep;

import std.format;
import std.getopt;
import std.path;
import std.stdio;
import std.array;
import std.file : exists;
import std.range;
import tagion.crypto.SecureNet;
import tagion.tools.revision;
import tagion.basic.Types : FileExtension, Buffer;
import tagion.tools.Basic;
import tagion.hibon.HiBONFile : fwrite, fread;
import tagion.basic.tagionexceptions;
import tagion.utils.Term;
import tagion.hibon.Document;
import tagion.tools.boot.genesis;
import tagion.hibon.HiBONFile : HiBONRange;
import tagion.hibon.HiBONJSON : toPretty;

alias check = Check!TagionException;

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool standard_output;
    bool standard_input;
    string output_filename;
    try {
        standard_input = (args.length == 1);
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch, //        "invoice|i","Sets the HiBON input file name", &invoicefile,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "c|stdout", "Print to standard output", &standard_output,//               "o|output", format("Output filename : Default %s", output_filename), &output_filename, // //        "output_filename|o", format("Sets the output file name: default : %s", output_filenamename), &output_filenamename,
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

        if (args.length == 1) {
            File fin;
            fin = stdin;
            File fout;
            fout = stdout;
            foreach (no, doc; HiBONRange(fin).enumerate) {
                fout.writefln("%d:%s", no, doc.toPretty);
            }
        }
    }
    catch (Exception e) {
        error(e);
        return 1;

    }
    return 0;
}
