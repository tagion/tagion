module tagion.tools.wasmutil.wasmutil;

import std.getopt;
import std.stdio;
import std.file : fread = read, fwrite = write, exists, readText;
import std.format;
import std.path : extension, setExtension;
import std.traits : EnumMembers;
import std.exception : assumeUnique;
import std.json;
import std.range : only, empty;
import std.meta;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.basic : basename;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.hibon.HiBONJSON;
import tagion.wasm.WasmWat : wat;
import tagion.wasm.WasmBetterC : wasmBetterC;
import tagion.wasm.WasmReader;
import tagion.wasm.WasmWriter;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmGas;
import tagion.wasm.WasmException;

//import tagion.script.StandardRecords;
import std.array : join;
import tagion.tools.Basic : Main;
import tagion.tools.revision;

template Produce(FileExtension ext) {
    static if (ext == FileExtension.wat) {
        import tagion.wasm.WasmWat;

        alias Produce = wat;
    }
    else static if (ext == FileExtension.dsrc) {
        import tagion.wasm.WasmBetterC;

        alias Produce = wasmBetterC;
    }
    else {
        static assert(0, format("Can not produce a %s format not supported", ext));
    }
}

void produce(FileExtension ext)(WasmReader wasm_reader, File fout) {
    Produce!(ext)(wasm_reader, fout).serialize;
}

enum OutputType {
    wat, /// WASM text output type in wat format (FileExtension.wat) 
    wasm, /// WASM binary output type (FileExtension.wasm)
    betterc, /// BetterC source file (FileExtension.dsrc)
}

FileExtension typeExtension(const OutputType type) pure nothrow @nogc {
    final switch (type) {
    case OutputType.wat:
        return FileExtension.wat;
    case OutputType.wasm:
        return FileExtension.wasm;
    case OutputType.betterc:
        return FileExtension.dsrc;
    }
}

mixin Main!_main;

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;

    string inputfilename;
    string outputfilename;
    //bool print;
    //bool betterc;
    bool inject_gas;
    bool verbose_switch;
    string[] modify_from;
    string[] modify_to;

    OutputType type;
    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch, //"inputfile|i", "Sets the HiBON input file name", &inputfilename,
                //"outputfile|o", "Sets the output file name", &outputfilename, // "bin|b", "Use HiBON or else use JSON", &binary,
                // "value|V", format("Bill value : default: %d", value), &value,
                "gas|g", format("Inject gas countes: %s", inject_gas), &inject_gas,
                "verbose|v", format("Verbose %s", verbose_switch), &verbose_switch,
                "mod|m", "Modify import module name from ", &modify_from,
                "to", "Modify import module name from ", &modify_to, //                "print|p", format("Print the wasm as wat: %s", print), &print,
                //                "betterc|d", format("Print the wasm as wat: %s", betterc), &betterc,

                "type|t", format("Sets stdout file type (%-(%s %))", [EnumMembers!OutputType]), &type,

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
                    format("<in-file>           Is an input file in (%-(%s -%)) format",
                        only(FileExtension.wasm, FileExtension.wat)),
                    format("<out-file>          Is an output file in (%-(%s -%)) format",
                        only(FileExtension.wat, FileExtension.dsrc)),
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

        version (none)
            if (verbose_switch && (!print || outputfilename.length is 0)) {
                verbose.mode = VerboseMode.STANDARD;
            }

        if (main_args.helpWanted) {
            help;
            return 0;
        }

        writefln("args=%s", args);
        foreach (file; args[1 .. $]) {
            with (FileExtension) {
                switch (file.extension) {
                case wasm:
                case wat:
                    if (inputfilename.empty) {
                        inputfilename = file;
                        break;
                    }
                    check(outputfilename is null,
                            format("Only one outputfile allowed (both %s and %s has been specifiled)",
                            inputfilename, file));
                    outputfilename = file;
                    break;
                case dsrc:
                    check(outputfilename is null,
                            format("Only one outputfile allowed (both %s and %s has been specifiled)",
                            inputfilename, file));
                    outputfilename = file;
                    break;
                case wast:

                    if (inputfilename.empty) {
                        inputfilename = file;
                        writefln("WAST %s", inputfilename);
                        type = OutputType.wasm;

                    }

                    break;
                default:
                    check(0, format("File %s is not supported", file));
                }
            }
        }
        if (modify_from.length !is modify_to.length) {
            stderr.writefln("Modify set must be set in pair");
            stderr.writefln("mod=%s", modify_from);
            stderr.writefln("to=%s", modify_to);
            help;
            return 4;
        }

        immutable standard_output = (outputfilename.length == 0);

        WasmReader wasm_reader;
        WasmWriter wasm_writer;
        with (FileExtension) {
            switch (inputfilename.extension) {
            case wasm, wo:
                immutable read_data = assumeUnique(cast(ubyte[]) fread(inputfilename));
                wasm_reader = WasmReader(read_data);
                verbose.hex(0, read_data);
                wasm_writer = WasmWriter(wasm_reader);
                break;
            case wast:
                import tagion.wasm.WastTokenizer;
                import tagion.wasm.WastParser;

                immutable wast_text = inputfilename.readText;
                auto tokenizer = WastTokenizer(wast_text);
                wasm_writer = new WasmWriter;
                auto wast_parser = WastParser(wasm_writer);
                wast_parser.parse(tokenizer);
                writefln("Before wasmwrite");
                writefln("wasm_writer=%(%02X %)", wasm_writer.serialize);
                break;
            default:
                check(0, format("File extensions %s not valid for input file (only %-(%s, %))",
                        inputfilename.extension, only(FileExtension.wasm, FileExtension.wo)));
            }
        }

        //WasmWriter wasm_writer = WasmWriter(wasm_reader);

        if (inject_gas) {
            auto wasmgas = WasmGas(wasm_writer);
            wasmgas.modify;
        }
        immutable data_out = wasm_writer.serialize;
        writefln("after data_out");
        if (verbose_switch) {
            verbose.mode = VerboseMode.STANDARD;
        }

        const output_extension = (outputfilename.empty) ? type.typeExtension : outputfilename.extension;
        writefln("Extension %s", output_extension);
        with (FileExtension) {
        WasmOutCase:
            switch (output_extension) {
                static foreach (WasmOut; AliasSeq!(wat, dsrc)) {
            case WasmOut:
                    File fout = stdout;
                    if (!outputfilename.empty) {
                        fout = File(outputfilename, "w");
                    }
                    scope (exit) {
                        if (fout !is stdout) {
                            fout.close;
                        }
                    }
                    produce!WasmOut(WasmReader(data_out), fout);
                    // produce!(FileExtension.wat)(WasmReader(data_out), outputfilename);
                    //   import _wast=tagion.wasm.Wat;
                    //       _wast.wat(WasmReader(data_out), stdout).serialize;
                    break WasmOutCase;
                }
            case wasm:
                if (outputfilename.empty) {
                    outputfilename = inputfilename.setExtension(FileExtension.wasm);
                }
                writefln("Write wasm %s", outputfilename);
                outputfilename.fwrite(data_out);
                break;
            default:
                check(outputfilename is null,
                        format("File extensions %s not valid output file (only %s)",
                        outputfilename.extension,
                        only(FileExtension.wasm, FileExtension.wat)));
                version (none)
                    if (print) {
                        Wat(wasm_reader, stdout).serialize();
                    }
            }
        }
    }
    catch (Exception e) {
        //verbose(e);
        stderr.writefln("Error: %s", e.msg);
    }
    return 0;
}
