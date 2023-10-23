module tagion.tools.boot.stiefel;

import std.format;
import std.getopt;
import std.path;
import std.stdio;
import std.array;
import std.file : exists;
import tagion.crypto.SecureNet;
import tagion.dart.Recorder;
import tagion.tools.revision;
import tagion.basic.Types : FileExtension, Buffer;
import tagion.tools.Basic;
import tagion.hibon.HiBONFile : fwrite, fread;
import tagion.basic.tagionexceptions;
import tagion.utils.Term;
import tagion.hibon.Document;
import tagion.tools.boot.genesis;
import tagion.hibon.HiBONFile;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.basic.basic : isinit;
import tagion.script.TagionCurrency;

alias check = Check!TagionException;

mixin Main!(_main, "tagionboot");

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool standard_output;
    bool standard_input;
    bool account;
    string[] nodekeys;
    string output_filename = "dart".setExtension(FileExtension.hibon);
    const net = new StdHashNet;
    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch, //"c|stdout", "Print to standard output", &standard_output,
                "o|output", format("Output filename : Default %s", output_filename), &output_filename, // //        "output_filename|o", format("Sets the output file name: default : %s", output_filenamename), &output_filenamename,
                "p|nodekey", "Node channel key(Pubkey) ", &nodekeys,
                "a|account", "Accumulates all bills in the input", &account, //         "bills|b", "Generate bills", &number_of_bills,
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
        auto factory = RecordFactory(net);
        auto recorder = factory.recorder;
        standard_input = (args.length == 1) && (nodekeys.empty);
        standard_output = output_filename.empty;
        if (standard_output) {
            vout = stderr;
        }
        if (!nodekeys.empty) {
            auto genesis_list = createGenesis(nodekeys, Document.init);
            recorder.insert(genesis_list, Archive.Type.ADD);
        }
        if (standard_input) {
            auto fin = stdin;
            TagionHead tagion_head;

            foreach (doc; HiBONRange(fin)) {
                if (account) {
                    if (TagionBill.isRecord(doc)) {
                        const bill = TagionBill(doc);
                        tagion_head.globals.total += bill.value.units;
                    }
                }
                else {

                    recorder.add(doc);
                }
            }
            if (!tagion_head.isinit) {
                tagion_head.name = TagionDomain;
                const total = tagion_head.globals.total;
                verbose("Total %s.%09sTGN", total / TagionCurrency.BASE_UNIT, total % TagionCurrency.BASE_UNIT);
                recorder.add(tagion_head);
            }
        }
        else {
            foreach (file; args[1 .. $]) {
                check(file.exists, format("File %s not found!", file));
                const doc = file.fread;
                recorder.add(doc);
            }
        }
        if (standard_output) {
            stdout.rawWrite(recorder.toDoc.serialize);
            return 0;
        }

        output_filename.fwrite(recorder);
    }
    catch (Exception e) {
        error(e);
        return 1;

    }
    return 0;
}
