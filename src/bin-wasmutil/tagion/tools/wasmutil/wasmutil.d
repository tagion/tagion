module tagion.tools.wasmutil.wasmutil;

import std.exception : assumeUnique;
import std.file : exists, fread = read, readText, fwrite = write;
import std.format;
import std.getopt;
import std.json;
import std.meta;
import std.path : baseName, extension, setExtension;
import std.range : empty, only;
import std.stdio;
import std.traits : EnumMembers;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.basic.basic : basename;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONJSON;
import tagion.wasm.WasmBase;
import tagion.wasm.WasmBetterC : wasmBetterC;
import tagion.wasm.WasmException;
import tagion.wasm.WasmGas;
import tagion.wasm.WasmReader;
import tagion.wasm.WasmWat : wat;
import tagion.wasm.WasmWriter;

//import tagion.script.StandardRecords;
import std.array : join;
import tagion.tools.Basic;
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

auto produce(FileExtension ext)(WasmReader wasm_reader, File fout) {
    return Produce!(ext)(wasm_reader, fout);
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
    string module_name;
    string[] imports;
    string[] attributes;
    bool inject_gas;
    //bool verbose_switch;

    string[] modify_from;
    string[] modify_to;

    OutputType type;
    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch, 
                "gas|g", format("Inject gas counters: %s", inject_gas), &inject_gas,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "mod|m", "Modify import module name from ", &modify_from,
                "to", "Modify import module name from ", &modify_to,
                "imports|i", "Import list", &imports,
                "name", "Import list", &module_name, //                "print|p", format("Print the wasm as wat: %s", print), &print,

                //                "betterc|d", format("Print the wasm as wat: %s", betterc), &betterc,

                "type|t", format("Sets stdout file type (%-(%s %))", [EnumMembers!OutputType]), &type,
        "global-attribute", "Sets the global attribute for the D transpiling", &attributes,
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
                    "                    stdout is used of the output is not specified the",
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
            if (__verbose_switch && (!print || outputfilename.length is 0)) {
                verbose.mode = VerboseMode.STANDARD;
            }

        if (main_args.helpWanted) {
            help;
            return 0;
        }

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
                        type = OutputType.wasm;

                    }

                    if (module_name.empty) {
                        module_name = inputfilename.baseName(FileExtension.wast);
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
                wasm_verbose.hex(0, read_data);
                wasm_writer = WasmWriter(wasm_reader);
                break;
            case wast:
                import tagion.wasm.WastParser;
                import tagion.wasm.WastTokenizer;

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
        if (__verbose_switch) {
            wasm_verbose.mode = VerboseMode.STANDARD;
        }

        const output_extension = (outputfilename.empty) ? type.typeExtension : outputfilename.extension;
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
                    auto prod = produce!WasmOut(WasmReader(data_out), fout);
                    static if (__traits(hasMember, prod, "module_name")) {
                        writefln("BetterC");
                        prod.module_name = module_name;
                        prod.imports = imports;
                        prod.attributes = attributes;
                    }
                    // produce!(FileExtension.wat)(WasmReader(data_out), outputfilename);
                    //   import _wast=tagion.wasm.Wat;
                    //       _wast.wat(WasmReader(data_out), stdout).serialize;
                    prod.serialize;
                    break WasmOutCase;
                }
            case wasm:
                if (outputfilename.empty) {
                    outputfilename = inputfilename.setExtension(FileExtension.wasm);
                }
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
        error(e);
        return 1;
    }
    return 0;
}
