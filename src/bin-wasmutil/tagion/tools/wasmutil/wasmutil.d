module tagion.tools.wasmutil.wasmutil;

import std.getopt;
import std.stdio;
import std.file : fread = read, fwrite = write, exists;
import std.format;
import std.path : extension;
import std.traits : EnumMembers;
import std.exception : assumeUnique;
import std.json;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.basic : basename;
import tagion.basic.Types : Buffer;
import tagion.hibon.HiBONJSON;
import tagion.wasm.Wast;
import tagion.wasm.WasmReader;
import tagion.wasm.WasmWriter;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmGas;

//import tagion.script.StandardRecords;
import std.array : join;
import tagion.tools.revision;

// import tagion.vm.wasm.revision;

version (none) enum fileextensions {
    wasm = ".wasm",
    wo = ".wo",
    wast = ".wast",

    json = ".json"
}

mixin Main!_main;

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;

    string inputfilename;
    string outputfilename;
    bool print;
    bool inject_gas;
    bool verbose_switch;
    string[] modify_from;
    string[] modify_to;

    auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "inputfile|i", "Sets the HiBON input file name", &inputfilename,
            "outputfile|o", "Sets the output file name", &outputfilename, // "bin|b", "Use HiBON or else use JSON", &binary,
            // "value|V", format("Bill value : default: %d", value), &value,
            "gas|g", format("Inject gas countes: %s", inject_gas), &inject_gas,
            "verbose|v", format("Verbose %s", verbose_switch), &verbose_switch,
            "mod|m", "Modify import module name from ", &modify_from,
            "to|t", "Modify import module name from ", &modify_to,
            "print|p", format("Print the wasm as wast: %s", print), &print,
    );

    void help() {
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
                // "<out-file>          Is an output file in .json or .hibon format",
                "                    stdout is used of the output is not specifed the",
                "",

                "<option>:",

                ].join("\n"),
                main_args.options);
    }

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    if (verbose_switch && (!print || outputfilename.length is 0)) {
        verbose.mode = VerboseMode.STANDARD;
    }

    if (main_args.helpWanted) {
        help;
        return 0;
    }
    //    writefln("args=%s", args);
    if (args.length > 3) {
        stderr.writefln("Only one output file name allowed (given %s)", args[1 .. $]);
        help;
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
        help;
        return 1;
    }

    if (modify_from.length !is modify_to.length) {
        stderr.writefln("Modify set must be set in pair");
        stderr.writefln("mod=%s", modify_from);
        stderr.writefln("to=%s", modify_to);
        help;
        return 4;
    }

    immutable standard_output = (outputfilename.length == 0);

    const input_extension = inputfilename.extension;

    WasmReader wasm_reader;
    with (FileExtension) {
        switch (input_extension) {
        case wasm, wo:
            immutable read_data = assumeUnique(cast(ubyte[]) fread(inputfilename));
            wasm_reader = WasmReader(read_data);
            verbose.hex(0, read_data);
            //        writefln("reader\n%s", read_data);
            break;
            /*
    case fileextensions.JSON:
        const data=cast(char[])fread(inputfilename);
        auto parse=data.parseJSON;
        auto hibon=parse.toHiBON;
        if (standard_output) {
            write(hibon.serialize);
        }
        else {
            outputfilename.fwrite(hibon.serialize);
        }
        break;
        */
        default:
            stderr.writefln("File extensions %s not valid for input file (only %s)",
                    input_extension, [EnumMembers!fileextensions]);
        }
    }
    // Wast(wasm_reader, stdout).serialize();
    // return 0;

    WasmWriter wasm_writer = WasmWriter(wasm_reader);

    // writeln("writer");
    // foreach(i, d; wasm_writer.serialize) {
    //     writef("%d ", d);
    //     if (i % 20 == 0) {
    //         writeln();
    //     }
    // }
    // writefln("writer\n%s", wasm_writer.serialize);
    // return 0;
    if (modify_from) {
    }
    if (inject_gas) {
        auto wasmgas = WasmGas(wasm_writer);
        wasmgas.modify;
        //        auto wasm_writer=WasmWriter(wasm_reader);
    }
    version (none)
        static foreach (E; EnumMembers!Section) {
            static if (E !is Section.CUSTOM && E !is Section.START) {
                {
                    auto sec = wasm_writer.mod[E];
                    if (sec !is null) {
                        writefln("\n\n%s=%s", E, sec);
                        foreach (i, s; sec.sectypes[]) {
                            writefln("%d s=%s", i, s);
                            import std.outbuffer;

                            auto bout = new OutBuffer;
                            s.serialize(bout);
                            writefln(" %s\n", bout.toBytes);
                        }
                    }
                }
            }
        }

    immutable data_out = wasm_writer.serialize;

    if (verbose_switch) {
        verbose.mode = VerboseMode.STANDARD;
    }

    if (print) {
        //        writefln("data_out=%s", data_out);
        // writefln("wasm_writer=%s", wasm_writer.serialize);
        //        Wast(WasmReader(data_out), stdout).serialize();
        Wast(wasm_reader, stdout).serialize();
        verbose.mode = VerboseMode.NONE;
    }

    if (outputfilename) {
        const output_extension = outputfilename.extension;
        with (FileExtension) {
            switch (output_extension) {
            case wasm:
                // auto fout=File(outputfilename, "w");
                // scope(exit) {
                //     fout.close;
                // }
                // fout.write(data_out);
                outputfilename.fwrite(data_out);
                // immutable read_data=assumeUnique(cast(ubyte[])fread(inputfilename));
                // wasm_reader=WasmReader(read_data);
                break;
            case wast:
                auto fout = File(outputfilename, "w");
                scope (exit) {
                    fout.close;
                }
                //            Wast(WasmReader(data_out), fout).serialize;
                Wast(WasmReader(data_out), fout).serialize;
                break;
            default:
                stderr.writefln("File extensions %s not valid output file (only %s)",
                        output_extension, only(FileExtension.wasm, FileExtension.wast));
            }
        }
    }
    return 0;
}
