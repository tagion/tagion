@description("Create boot dart db files")
module tagion.tools.boot.stiefel;

import std.array;
import std.file : exists;
import std.format;
import std.getopt;
import std.path;
import std.stdio;
import std.algorithm;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.basic.basic : isinit;
import tagion.errors.tagionexceptions;
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
    // Could use some info about available memory to automatically determine this?
    long max_archives_per_recorder = 0;
    string genesis;
    bool trt;
    string[] nodekeys;
    string output_filename = "dart".setExtension(FileExtension.hibon);
    const net = new StdHashNet;
    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "o|output", format("Output filename : default %s", output_filename), &output_filename,
                "p|nodekey", "Node channel key(Pubkey) ", &nodekeys,
                "t|trt", "Generate a recorder from a list of bill files for the trt", &trt,
                "a|account", "Accumulates all bills in the input", &account,
                "g|genesis", "Genesis document", &genesis,
                "maxarchives", format("Maximum amount of archives per recorder, 0=nolimit : default: %s", max_archives_per_recorder), &max_archives_per_recorder,
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
        File fout;
        if (standard_output) {
            vout = stderr;
        }
        else {
            fout = File(output_filename, "a");
        }

        void write_recorder(RecordFactory.Recorder recorder) {
            if (standard_output) {
                stdout.rawWrite(recorder.toDoc.serialize);
                return;
            }
            verbose("write to %s", output_filename);
            fout.fwrite(recorder);
        }

        void recorder_add(A)(A archive) {
            recorder.insert(archive, Archive.Type.ADD);
            if(max_archives_per_recorder <= 0 || recorder.length < max_archives_per_recorder) {
                return;
            }
            write_recorder(recorder);
            destroy(recorder);
            recorder = factory.recorder;
        }

        verbose("standard_input: %s, args %s", standard_input, args);
        if (!nodekeys.empty && standard_input) {
            auto fin = stdin;

            BigNumber total;
            long start_bills;
            foreach (doc; HiBONRange(fin)) {
                if (doc.isRecord!TagionBill) {
                    const bill = TagionBill(doc);
                    total += bill.value.units;
                    start_bills += 1;
                    recorder_add(bill);
                }
            }
            TagionGlobals genesis_globals;
            genesis_globals.total = total;
            genesis_globals.total_burned = 0;
            genesis_globals.number_of_bills = start_bills;
            genesis_globals.burnt_bills = 0;
            verbose("Total %s.%09sTGN", total / TagionCurrency.BASE_UNIT, total % TagionCurrency.BASE_UNIT);

            Document testamony;
            if (genesis) {
                check(genesis.exists, format("File %s not found!", genesis));
                testamony = genesis.fread;
            }
            auto genesis_list = createGenesis(nodekeys, testamony, genesis_globals);
            recorder_add(genesis_list);
        }
        else if (standard_input) {
            auto fin = stdin;
            if (trt) {
                // FIXME use a range instead of reallocating all the bills
                TagionBill[] bills;
                foreach (doc; HiBONRange(fin)) {
                    if (doc.isRecord!TagionBill) {
                        bills ~= TagionBill(doc);
                    }
                }
                import tagion.trt.TRT;

                genesisTRT(bills, recorder, net);
            }
            else {
                auto hrange = HiBONRange(fin);
                foreach(doc; hrange) {
                    recorder_add(doc);
                }
            }
        }
        else {
            foreach (file; args[1 .. $]) {
                check(file.exists, format("File %s not found!", file));
                const doc = file.fread;
                recorder_add(doc);
            }
        }
        write_recorder(recorder);
    }
    catch (Exception e) {
        error(e);
        return 1;

    }
    return 0;
}
