module tagion.tools.hirep.hirep;

import std.array;
import std.file : exists;
import std.format;
import std.getopt;
import std.path;
import std.range;
import std.stdio;
import std.conv : to;
import std.algorithm;
import tagion.basic.Types;
import tagion.basic.tagionexceptions;
import tagion.crypto.SecureNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONFile : HiBONRange;
import tagion.hibon.HiBONJSON : toPretty;
import tagion.hibon.HiBONregex : HiBONregex;
import tagion.tools.Basic;
import tagion.tools.boot.genesis;
import tagion.tools.revision;
import tagion.utils.Term;
import tools = tagion.tools.toolsexception;

alias check = Check!TagionException;

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    bool not_flag;
    string output_filename;
    string name;
    string record_type;
    string[] types;
    string list;
    bool recursive_flag;
    bool subhibon_flag;

    try {
        auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
            "v|verbose", "Prints more debug information", &__verbose_switch,
            "o|output", "Output file name (Default stdout)", &output_filename,
            "n|name", "HiBON member name (name as text or regex as `regex`)", &name,
            "r|recordtype", "HiBON recordtype (name as text or regex as `regex`)", &record_type,
            "t|type", "HiBON data types", &types,
            "not", "Filter out match", &not_flag,
            "l|list", "List of indices in a hibon stream (ex. 1,10,20..23)", &list,
            "R|recursive", "Enables recursive search", &recursive_flag,
            "s|subhibon", "Output only subhibon that match criteria", &subhibon_flag,
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
                format("%s [<option>...] [<hibon-files>...]", program),
                "",
                "<option>:",

            ].join("\n"),
            main_args.options);
            return 0;
        }
        bool inList(const size_t no) {
            if (list.empty) {
                return true;
            }
            foreach (elm; list.splitter(",")) {
                const elm_range = elm.split("..");
                if (elm_range.length == 1 && no == elm_range[0].to!size_t) {
                    return true;
                }
                if (elm_range.length == 2 && (elm_range[0].to!size_t <= no) && (elm_range[1] == "-1" || no < elm_range[1]
                        .to!size_t)) {
                    return true;
                }
            }
            return false;
        }

        if (name) {
            verbose("name:        [%s]", name);
            verbose("record type: [%s]", record_type);
            verbose("types:       %s", types);
        }
        HiBONregex hibon_regex;
        if (name) {
            hibon_regex.name = name;
        }
        if (record_type) {
            hibon_regex.record_type = record_type;
        }
        tools.check(args.length <= 2, "Only one file argument accepted");
        File fin;
        fin = stdin;
        if (args.length == 2) {
            const file_name = args[1];
            tools.check(file_name.hasExtension(FileExtension.hibon),
                format("Input %s should be a .%s file", file_name, FileExtension.hibon));
            fin = File(file_name, "r");
        }
        else {
            fin = stdin;
            vout = stderr;
        }
        File fout;
        if (output_filename.empty) {
            fout = stdout;
        }
        else {
            tools.check(output_filename.hasExtension(FileExtension.hibon),
                format("Output %s should be a .%s file", output_filename, FileExtension.hibon));
            fout = File(output_filename, "w");
        }
        scope (exit) {
            if (fout != stdout) {
                fout.close;
            }
        }

        Document[] getMatchDocs(Document doc) {
            if (hibon_regex.match(doc))
                return [doc];

            if (!recursive_flag)
                return [];

            // Going recursive
            Document[] docs;
            foreach (elem; doc[]) {
                if (!(elem.isType!Document))
                    continue; // Skip non-Document records

                docs ~= getMatchDocs(elem.get!Document);
            }

            return docs;
        }

        void output(Document[] docs) {
            foreach (doc; docs) {
                verbose("%s", doc.toPretty);
                fout.rawWrite(doc.serialize);
            }
        }

        foreach (no, doc; HiBONRange(fin).enumerate) {
            if (!inList(no)) // Empty list is true
                continue;

            auto match_docs = getMatchDocs(doc);
            if (match_docs.empty)
                continue;

            if (subhibon_flag)
                output(match_docs);
            else
                output([doc]);
        }
    }
    catch (Exception e) {
        error(e);
        return 1;

    }
    return 0;
}
