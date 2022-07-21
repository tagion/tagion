module tagion.tools.hibonutil;

import std.getopt;
import std.stdio;
import std.file : fread = read, fwrite = write, exists, readText;
import std.format;
import std.exception : assumeUnique, assumeWontThrow;
import std.json;
import std.range : only;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.basic.Types : FileExtension;
import tagion.basic.Basic : fileExtension;
import tagion.hibon.HiBONJSON;
import std.utf : toUTF8;

import std.array : join;

import tagion.tools.Basic;

mixin Main!_main;

enum BOM_UTF8_HEADER_SIGNATURE = char(239);
enum BOM_UTF8_HEADER_SIZE = 3;

/**
 * @brief convert raw text to JSON object
 */
private JSONValue raw2Json(const string text)
{
    JSONValue result = null;
    auto size = text.length;
    if (size > 0)
    {
        // fix issues with BOM
        if ((text[0] == BOM_UTF8_HEADER_SIGNATURE) && (size > (BOM_UTF8_HEADER_SIZE - 1)))
        {
            result = raw2Json(text[BOM_UTF8_HEADER_SIZE .. size]);
        }
        else
        {
            try
            {
                result = text.parseJSON;
            }
            catch(JSONException e)
            {
                writeln(e.msg);
            }
        }
    }
    return result;
}

/**
 * @brief returned swaped copy of wide char elements array. (BE->LE, LE->BE)
 */
private wchar[] swapedcopy(const wchar[] data)
{
    ulong i = 0;
    wchar[] sw_copy = data.dup;
    foreach(e ; data)
    {
        char* a = cast(char*)&e;
        char* b = cast(char*)&sw_copy[i];
        i++;
        b[0] = a[1];
        b[1] = a[0];
    }
    return sw_copy;
}

/**
 * @brief convert raw data to JSON object
 */
private JSONValue raw2Json(const void[] data)
{
    import std.encoding;
    JSONValue result = null;
    const size = data.length;
    if (size > 0)
    {
       auto bom = getBOM(cast(ubyte[])data);
       switch (bom.schema)
       {
            case BOM.none:
            case BOM.utf8:
                const char[] line = cast(char[])data;
                result = raw2Json(cast(string)line);
                break;
            case BOM.utf16be:
                result = raw2Json(swapedcopy(cast(wchar[])data));
                break;
            case BOM.utf16le:
                const wchar[] line = cast(wchar[])data;
                auto a = line.toUTF8;
                result = raw2Json(a);
                break;
            default:
                writeln("Unsuported encoding or damaged JSON file", bom);

       }
    }
    return result;
}

int _main(string[] args)
{
    immutable program = args[0];
    bool version_switch;

    string inputfilename;
    string outputfilename;
    bool pretty;
    auto logo = import("logo.txt");

    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version", "display the version", &version_switch,
        "inputfile|i", "Sets the HiBON input file name", &inputfilename,
        "outputfile|o", "Sets the output file name", &outputfilename,
        "pretty|p", format("JSON Pretty print: Default: %s", pretty), &pretty,
    );

    if (version_switch)
    {
        writefln("version %s", "1.9");
        return 0;
    }

    if (main_args.helpWanted)
    {
        writeln(logo);
        defaultGetoptPrinter(
            [
            "Documentation: https://tagion.org/",
            "",
            "Usage:",
            format("%s [<option>...] <in-file> <out-file>", program),
            format("%s [<option>...] <in-file>", program),
            "",
            "Where:",
            "<in-file>           Is an input file in .json or .hibon format",
            "<out-file>          Is an output file in .json or .hibon format",
            "                    stdout is used of the output is not specifed the",
            "",

            "<option>:",

        ].join("\n"),
        main_args.options);
        return 0;
    }

    if (args.length == 2)
    {
        inputfilename = args[1];
    }
    else if (args.length == 1 && !inputfilename)
    {
        stderr.writefln("Input file missing");
        return 1;
    }

    immutable standard_output = (outputfilename.length == 0);
    if (!exists(inputfilename))
    {
        writeln("File " ~ inputfilename ~ " not found");
        return 0;
    }

    switch (inputfilename.fileExtension)
    {
    case FileExtension.hibon:
        immutable data = assumeUnique(cast(ubyte[]) fread(inputfilename));
        const doc = Document(data);
        const error_code = doc.valid(
            (
                const(Document) sub_doc,
                const Document.Element.ErrorCode error_code,
                const(Document.Element) current, const(
                Document.Element) previous) nothrow{
            assumeWontThrow(writefln("%s", current));
            return true;
        });
        if (error_code !is Document.Element.ErrorCode.NONE)
        {
            writefln("Errorcode %s", error_code);
            return 1;
        }
        auto json = doc.toJSON;
        auto json_stringify = (pretty) ? json.toPrettyString : json.toString;
        if (standard_output)
        {
            writefln("%s", json_stringify);
        }
        else
        {
            outputfilename.fwrite(json_stringify);
        }
        break;
    case FileExtension.json:
        const data = inputfilename.fread;
        auto parse = data.raw2Json;
        HiBON hibon = null;
        try
        {
            hibon = parse.toHiBON;
        }
        catch(HiBON2JSONException e)
        {
            writeln("Conversion error, please validate input JSON file");
            return 1;
        }
        if (standard_output)
        {
            write(hibon.serialize);
        }
        else
        {
            outputfilename.fwrite(hibon.serialize);
        }
        break;
    default:
        stderr.writefln("File %s not valid (only %(.%s %))",
            inputfilename, only(FileExtension.hibon, FileExtension.json));
        return 1;
    }

    return 0;
}
