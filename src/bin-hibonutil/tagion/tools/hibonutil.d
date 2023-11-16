/// HiBON utility to convert and check HiBON format 
module tagion.tools.hibonutil;

import std.array : join;
import std.conv;
import std.encoding : BOM, BOMSeq;
import std.exception : assumeUnique, assumeWontThrow;
import std.exception : ifThrown;
import std.file : exists, fread = read, readText, fwrite = write;
import std.format;
import std.getopt;
import std.json;
import std.path : extension, setExtension;
import std.range : only;
import std.range;
import std.stdio;
import std.utf : toUTF8;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONtoText : decodeBase64, encodeBase64;
import tagion.tools.Basic;
import tagion.tools.revision;
import tools = tagion.tools.toolsexception;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.dart.DARTBasic : dartIndex;
import tagion.basic.Types;

mixin Main!_main;
/**
 * @brief wrapper for BOM extracting
 * @param str - extract BOM (byte order marker) for next correcting parsing text
 * \return BOM representation
 */
const(BOMSeq) getBOM(string str) @trusted {
    import std.encoding : _getBOM = getBOM;

    return _getBOM(cast(ubyte[]) str);
}

extern (C) {
    int ungetc(int c, FILE* stream);
}

void unget(ref File f, const(char) ch) @trusted {
    ungetc(cast(int) ch, f.getFP);
}

import tagion.hibon.HiBONBase;

@safe
struct Element {
    int type;
    int keyPos;
    uint keyLen;
    uint valuePos;
    uint dataSize;
    uint dataPos;
    string key;
    mixin HiBONRecord!(q{
            this(const(Document.Element) elm, const uint offset) {
                 type=elm.type;
                keyPos=elm.keyPos+offset;
              keyLen=elm.keyLen;
    valuePos=elm.valuePos+offset;
                dataPos=elm.dataPos+offset;
                dataSize=elm.dataSize;
                key=elm.key; 
            }
        });

}

version (none) Document.Element.ErrorCode check_document(const(Document) doc, out Document error_doc) {
    Document.Element.ErrorCode result;
    HiBON h_error;
    static struct ErrorElement {
        string error_code;
        Element element;
        mixin HiBONRecord;
    }

    ErrorElement[] errors;
    void error(
            const(Document) main_doc,
            const Document.Element.ErrorCode error_code,
            const(Document.Element) current, const(
            Document.Element) previous)
    nothrow {
        ErrorElement error_element;
        const offset = cast(uint)(&current.data[0] - &main_doc.data[0]);
        error_element.error_code = format("%s", error_code); //.to!string.ifThrown!Exception("<Bad error>");
        error_element.element = Element(current, offset);
        errors ~= error_element;
        result = (result is result.init) ? error_code : result;
    }

    if (!errors.empty) {
        auto h_error = new HiBON;
        h_error["errors"] = errors;
        error_doc = Document(h_error);
    }
    return result;
}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;

    bool standard_output;
    bool stream_output;
    bool pretty;
    bool sample;
    bool hibon_check;
    bool reserved;
    bool input_json;
    bool input_text;
    bool output_base64;
    bool output_hex;
    bool output_hash;
    bool output_dartindex;
    bool ignore;
    string outputfilename;
    const net = new StdHashNet;
    auto logo = import("logo.txt");

    GetoptResult main_args;
    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "c|stdout", "Print to standard output", &standard_output,
                "s|stream", "Parse .hibon file to stdout", &stream_output,
                "o|output", "Output filename only for stdin data", &outputfilename,
                "r|reserved", "Check reserved keys and types enabled", &reserved,
                "p|pretty", format("JSON Pretty print: Default: %s", pretty), &pretty,
                "J", "Input stream format json", &input_json,
                "t|base64", "Convert to base64 output", &output_base64,
                "x|hex", "Convert to hex output", &output_hex,
                "T|text", "Input stream base64 or hex-string", &input_text,
                "sample", "Produce a sample HiBON", &sample,
                "check", "Check the hibon format", &hibon_check,
                "H|hash", "Prints the hash value", &output_hash,
                "D|dartindex", "Prints the DART index", &output_dartindex,
                "ignore", "Ignore document valid check", &ignore,
        );
        if (sample) {
            string sample_file_name = "sample".setExtension(FileExtension.hibon);
            sample_file_name.fwrite(sampleHiBON.serialize);
            sample_file_name = "sample_array".setExtension(FileExtension.hibon);
            sample_file_name.fwrite(sampleHiBON(true).serialize);
            return 0;
        }
        if (version_switch) {
            revision_text.writeln;
            return 0;
        }

        if (main_args.helpWanted) {
            writeln(logo);
            defaultGetoptPrinter(
                    [
                    "Documentation: https://tagion.org/",
                    "",
                    "Usage:",
                    format("%s [<option>...] <in-file>", program),
                    "",
                    "Where:",
                    "<in-file>           Is an input file in .json or .hibon format",
                    "",

                    "<option>:",

                    ].join("\n"),
                    main_args.options);
            return 0;
        }
        if (output_hash || output_dartindex) {
            output_hex = !output_base64;
        }
        tools.check(!input_json || !input_text, "Input stream can not be defined as both JSON and text-format");
        if (standard_output || stream_output) {
            vout = stderr;
        }
        const reserved_flag = cast(Document.Reserved) reserved;
        if (args.length == 1) {
            auto fin = stdin;
            File fout;
            fout = stdout;
            if (!outputfilename.empty) {
                fout = File(outputfilename, "w");
            }
            scope (exit) {
                if (fout !is stdout) {
                    fout.close;
                }
            }
            void print(const(Document) doc) {
                Buffer stream = doc.serialize;
                if (output_hash) {
                    stream = net.rawCalcHash(stream);
                }
                else if (output_dartindex) {
                    stream = cast(Buffer) net.dartIndex(doc);
                }
                if (output_base64) {
                    fout.writeln(stream.encodeBase64);
                    return;
                }
                if (output_hex) {
                    fout.writefln("%(%02x%)", stream);
                    return;
                }
                if (pretty || standard_output) {
                    const json_stringify = (pretty) ? doc.toPretty : doc.toJSON.toString;
                    fout.writeln(json_stringify);
                    return;
                }
                fout.rawWrite(stream);

            }

            if (input_text) {
                foreach (no, line; fin.byLine.enumerate(1)) {
                    immutable data = line.decodeBase64;
                    const doc = Document(data);
                    verbose("%d:%s", no, line);
                    print(doc);
                }
                return 0;
            }
            if (input_json) {
                foreach (no, json_stringify; fin.byLine.enumerate(1)) {
                    const doc = json_stringify.toDoc; //parseJSON.toHiBON;
                    verbose("%d:%s", no, json_stringify);
                    print(doc);
                }
                return 0;
            }

            import tagion.hibon.HiBONFile : HiBONRange;

            foreach (no, doc; HiBONRange(fin).enumerate) {
                verbose("%d: doc-size=%d", no, doc.full_size);

                if (!ignore) {
                    const error_code = doc.valid(
                            (
                            const(Document) sub_doc,
                            const Document.Element.ErrorCode error_code,
                            const(Document.Element) current, const(
                            Document.Element) previous) nothrow{ return true; }, reserved_flag);
                    tools.check(error_code is Document.Element.ErrorCode.NONE,
                            format("Streamed document %d faild with %s", no, error_code));
                }
                print(doc);
            }
            return 0;
        }

        loop_files: foreach (inputfilename; args[1 .. $]) {
            if (!inputfilename.exists) {
                stderr.writefln("Error: file %s does not exist", inputfilename);
                return 1;
            }
            switch (inputfilename.extension) {
            case FileExtension.hibon:
                immutable data = assumeUnique(cast(ubyte[]) fread(inputfilename));
                const doc = Document(data);

                if (!ignore) {
                    const error_code = doc.valid(
                            (
                            const(Document) sub_doc,
                            const Document.Element.ErrorCode error_code,
                            const(Document.Element) current, const(
                            Document.Element) previous) nothrow{ assumeWontThrow(writefln("%s", current)); return true; },
                            reserved_flag);
                    if (error_code !is Document.Element.ErrorCode.NONE) {
                        stderr.writefln("Error: Document errorcode %s", error_code);
                        return 1;
                    }
                }
                if (output_base64 || output_hex) {
                    Buffer stream = doc.serialize;
                    if (output_hash) {
                        stream = net.rawCalcHash(stream);
                    }
                    else if (output_dartindex) {
                        stream = cast(Buffer) net.dartIndex(doc);
                    }

                    const text_output = (output_hex) ? format("%(%02x%)", stream) : stream.encodeBase64;
                    if (standard_output) {
                        writefln("%s", text_output);
                        continue loop_files;
                    }
                    inputfilename.setExtension(FileExtension.text).fwrite(text_output);

                    continue loop_files;
                }
                if (stream_output) {
                    stdout.rawWrite(doc.serialize);
                    continue loop_files;
                }
                auto json = doc.toJSON;
                auto json_stringify = (pretty) ? json.toPrettyString : json.toString;
                if (standard_output) {
                    writefln("%s", json_stringify);
                    continue loop_files;
                }
                inputfilename.setExtension(FileExtension.json).fwrite(json_stringify);
                break;
            case FileExtension.json:
                string text;
                text = inputfilename.readText;
                const bom = getBOM(text);
                with (BOM) switch (bom.schema) {
                case utf8:
                    text = text[bom.sequence.length .. $];
                    break;
                case none:
                    //do nothing
                    break;
                default:
                    stderr.writefln("File type %s not supported", bom.schema);
                    return 1;
                }

                HiBON hibon;
                try {
                    auto parse = text.parseJSON;
                    hibon = parse.toHiBON;
                }
                catch (HiBON2JSONException e) {
                    stderr.writefln("Error: HiBON-JSON format in the %s file", inputfilename);
                    error(e);
                    return 1;
                }
                catch (JSONException e) {
                    stderr.writeln("Error: JSON syntax");
                    error(e);
                    return 1;
                }
                catch (Exception e) {
                    error(e);
                    return 1;
                }
                if (standard_output) {
                    stdout.rawWrite(hibon.serialize);
                    continue loop_files;
                }
                inputfilename.setExtension(FileExtension.hibon).fwrite(hibon.serialize);
                break;
            case FileExtension.text:
                string text;
                text = inputfilename.readText;
                writefln("...");
                Document doc;
                doc = decodeBase64(text);
                if (standard_output) {
                    stdout.rawWrite(doc.serialize);
                    continue loop_files;
                }

                inputfilename.setExtension(FileExtension.hibon).fwrite(doc.serialize);
                break;
            default:
                error("File %s not valid (only %(.%s %))",
                        inputfilename, only(FileExtension.hibon, FileExtension.json, FileExtension.text));
                return 1;
            }
        }
    }
    catch (Exception e) {
        error(e);

        return 1;
    }
    return 0;
}

Document sampleHiBON(const bool hibon_array = false) {
    import std.datetime;
    import std.typecons;
    import tagion.hibon.BigNumber;
    import tagion.utils.StdTime;

    auto list = tuple!(
            "BIGINT",
            "BOOLEAN",
            "FLOAT32",
            "FLOAT64",
            "INT32",
            "INT64",
            "UINT32",
            "UINT64")(
            BigNumber("-1234_1234_4678_4678_9876_8438_2345_1111"),
            true,
            float(0x1.3ae148p+0),
            double(0x1.9b5d96fe285c6p+664),
            int(-42),
            long(-1234_1234_4678_4678),
            uint(42),
            ulong(1234_1234_4678_4678),
    );

    auto h = new HiBON;
    foreach (i, value; list) {
        if (hibon_array) {
            h[i] = value;
        }
        else {
            h[list.fieldNames[i]] = value;
        }
    }
    immutable(ubyte)[] buf = [1, 2, 3, 4];
    auto sub_list = tuple!(
            "BINARY",
            "STRING",
            "TIME")(
            buf,
            "Text",
            currentTime
    );
    auto sub_hibon = new HiBON;
    foreach (i, value; sub_list) {
        if (hibon_array) {
            sub_hibon[i] = value;
        }
        else {
            sub_hibon[sub_list.fieldNames[i]] = value;
        }
    }
    if (hibon_array) {
        h[list.length] = sub_hibon;
    }
    else {
        h["sub_hibon"] = sub_hibon;
    }

    return Document(h.serialize);

}
