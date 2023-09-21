module tagion.tools.boot.stiefel;

import std.format;
import std.getopt;
import std.path;
import std.stdio;
import std.array;
import tagion.tools.revision;
import tagion.basic.Types : FileExtension;
import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    string output_filename = "dartcrud".setExtension(FileExtension.hibon);
    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch, //        "invoice|i","Sets the HiBON input file name", &invoicefile,
            "output|o", format("Output filename : Default %s", output_filename), &output_filename, // //        "output_filename|o", format("Sets the output file name: default : %s", output_filenamename), &output_filenamename,
            //         "bills|b", "Generate bills", &number_of_bills,
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
    return 0;
}
