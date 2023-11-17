module tagion.tools.boot.stiefel;

import std.array;
import std.file : exists;
import std.format;
import std.getopt;
import std.path;
import std.stdio;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.basic.basic : isinit;
import tagion.basic.tagionexceptions;
import tagion.crypto.SecureNet;
import tagion.dart.Recorder;
import tagion.hibon.Document;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONFile;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.tools.Basic;
import tagion.tools.boot.genesis;
import tagion.tools.revision;
import tagion.utils.Term;
import tagion.hibon.BigNumber;
import tagion.hibon.HiBONRecord : isRecord;

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
        standard_input = (args.length == 1);
        standard_output = output_filename.empty;
        if (standard_output) {
            vout = stderr;
        }
        verbose("standard_input: %s, args %s", standard_input, args);
        if (!nodekeys.empty && standard_input) {
            auto fin = stdin;


            BigNumber total;
            long start_bills;
            foreach(doc; HiBONRange(fin)) {
                if (doc.isRecord!TagionBill) {
                    const bill = TagionBill(doc);
                    total += bill.value.units;
                    start_bills += 1;
                    recorder.insert(bill, Archive.Type.ADD);
                }
            }
            TagionGlobals genesis_globals;
            genesis_globals.total = total;
            genesis_globals.total_burned = 0;
            genesis_globals.number_of_bills = start_bills;
            genesis_globals.burnt_bills = 0;
            verbose("Total %s.%09sTGN", total / TagionCurrency.BASE_UNIT, total % TagionCurrency.BASE_UNIT);

            auto genesis_list = createGenesis(nodekeys, Document.init, genesis_globals);
            recorder.insert(genesis_list, Archive.Type.ADD);
            TagionHead tagion_head;
            tagion_head.name = TagionDomain;
            tagion_head.current_epoch = 0;
            recorder.add(tagion_head);
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
