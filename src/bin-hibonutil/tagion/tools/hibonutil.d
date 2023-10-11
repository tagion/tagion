/// HiBON utility to convert and check HiBON format 
module tagion.tools.hibonutil;

import std.getopt;
import std.stdio;
import std.file : fread = read, fwrite = write, exists, readText;
import std.path : setExtension, extension;
import std.format;
import std.exception : assumeUnique, assumeWontThrow;
import std.json;
import std.range : only;
import std.conv;
import std.range;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.Types : FileExtension, Buffer;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONtoText : encodeBase64, decodeBase64;
import std.utf : toUTF8;
import std.encoding : BOMSeq, BOM;
import tagion.hibon.HiBONRecord;
import std.array : join;

import tagion.tools.Basic;
import tagion.tools.revision;
import std.exception : ifThrown;

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

    //    string inputfilename;
    bool standard_output;
    //    string outputfilename;
    bool pretty;
    bool base64;
    bool sample;
    bool hibon_check;
    bool reserved;
    // bool verbose;
    string outputfilename;
    auto logo = import("logo.txt");

    GetoptResult main_args;
    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "c|stdout", "Print to standard output", &standard_output,
                "pretty|p", format("JSON Pretty print: Default: %s", pretty), &pretty,
                "b|base64", "Convert to base64 string", &base64,
                "v|verbose", "Print more debug information", &__verbose_switch,
                "o|output", "outputfilename only for stdin", &outputfilename,
                "r|reserved", "Check reserved keys and types enabled", &reserved,
                "sample", "Produce a sample HiBON", &sample,
                "check", "Check the hibon format", &hibon_check,
        );
        if (sample) {
            string sample_file_name = "sample".setExtension(FileExtension.hibon);
            writefln("Write %s", sample_file_name);
            sample_file_name.fwrite(sampleHiBON.serialize);
            sample_file_name = "sample_array".setExtension(FileExtension.hibon);
            writefln("Write %s", sample_file_name);
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
        const reserved_flag = cast(Document.Reserved) reserved;
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

            const error_code = doc.valid(
                    (
                    const(Document) sub_doc,
                    const Document.Element.ErrorCode error_code,
                    const(Document.Element) current, const(
                    Document.Element) previous) nothrow{ return true; }, reserved_flag);
            if (error_code is Document.Element.ErrorCode.NONE) {
                auto json = doc.toJSON;
                auto json_stringify = (pretty) ? json.toPrettyString : json.toString;
                if (standard_output) {
                    writefln("%s", json_stringify);
                    return 1;
                }
                if (outputfilename) {
                    outputfilename.setExtension(FileExtension.json).fwrite(json_stringify);
                    return 1;
                }
                json_stringify.writeln;

                return 1;
            }
            else {
                HiBON hibon;
                const text = cast(string) data;
                try {
                    auto parse = text.parseJSON;
                    hibon = parse.toHiBON;
                }
                catch (HiBON2JSONException e) {
                    stderr.writefln("Error: HiBON-JSON format in the %s file", outputfilename);
                    error(e);
                    return 1;
                }
                catch (JSONException e) {
                    stderr.writeln("Error: JSON syntax");
                    stderr.writefln("Error: HiBONError Document errorcode %s", error_code);
                    error(e);
                    return 1;
                }
                catch (Exception e) {
                    error(e);
                    stderr.writefln("Error: HiBONError Document errorcode %s", error_code);

                    return 1;
                }
                if (standard_output) {
                    stdout.rawWrite(hibon.serialize);
                    return 1;
                }

                if (outputfilename) {
                    outputfilename.setExtension(FileExtension.hibon).fwrite(hibon.serialize);
                    return 1;

                }

                stderr.writeln("Error: output not specified");
                return 1;
            }

            stderr.writefln("Input file missing");
            return 1;
        }

        foreach (inputfilename; args[1 .. $]) {
            if (!inputfilename.exists) {
                stderr.writefln("Error: file %s does not exist", inputfilename);
                return 1;
            }
            switch (inputfilename.extension) {
            case FileExtension.hibon, FileExtension.recchainblock:
                immutable data = assumeUnique(cast(ubyte[]) fread(inputfilename));
                const doc = Document(data);
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
                if (base64) {
                    const text_output = encodeBase64(doc);
                    if (standard_output) {
                        writefln("%s", text_output);
                        return 0;
                    }
                    inputfilename.setExtension(FileExtension.text).fwrite(text_output);

                    return 0;
                }
                auto json = doc.toJSON;
                auto json_stringify = (pretty) ? json.toPrettyString : json.toString;
                if (standard_output) {
                    writefln("%s", json_stringify);
                }
                else {
                    inputfilename.setExtension(FileExtension.json).fwrite(json_stringify);
                }
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
                    // writefln("%s", text);
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
                    stderr.writeln(e.msg);
                    return 1;
                }
                if (standard_output) {
                    stdout.rawWrite(hibon.serialize);
                }
                else {
                    if (standard_output) {
                        stdout.rawWrite(hibon.serialize);
                    }
                    else {
                        inputfilename.setExtension(FileExtension.hibon).fwrite(hibon.serialize);
                    }
                }
                break;
            case FileExtension.text:
                string text;
                text = inputfilename.readText;
                Document doc;
                doc = decodeBase64(text);
                if (standard_output) {
                    stdout.rawWrite(doc.serialize);
                    return 0;
                }
                inputfilename.setExtension(FileExtension.hibon).fwrite(doc.serialize);
                return 0;
            default:
                stderr.writefln("File %s not valid (only %(.%s %))",
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
    import tagion.hibon.BigNumber;
    import tagion.utils.StdTime;
    import std.typecons;
    import std.datetime;

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
