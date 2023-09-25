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
import tagion.hibon.HiBONRecord : fwrite, fread;
import tagion.basic.tagionexceptions;
import tagion.utils.Term;
import tagion.hibon.Document;

alias check = Check!TagionException;

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool standard_output;
    string output_filename = "dart".setExtension(FileExtension.hibon);
    const net = new StdHashNet;
    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch, //        "invoice|i","Sets the HiBON input file name", &invoicefile,
                "c|stdout", "Print to standard output", &standard_output,
                "o|output", format("Output filename : Default %s", output_filename), &output_filename, // //        "output_filename|o", format("Sets the output file name: default : %s", output_filenamename), &output_filenamename,
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
        auto factory = RecordFactory(net);
        auto recorder = factory.recorder;

        if (args.length == 1) {
            auto fin = stdin;
            ubyte[1024] buf;
            Buffer data;

            for (;;) {
                const read_buffer = fin.rawRead(buf);
                if (read_buffer.length is 0) {
                    break;
                }
                data ~= read_buffer;
            }

            const doc = Document(data);
            recorder.add(doc);
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
        writefln("%1$sError: %3$s%2$s", RED, RESET, e.msg);
        return 1;

    }
    return 0;
}
