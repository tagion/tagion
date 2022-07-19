module tagion.tools.behaviour;

import std.getopt;
import std.stdio;
import std.format;
import std.path : extension, setExtension;
import std.file : exists, dirEntries, SpanMode;
import std.string : join, splitLines;
import std.algorithm.iteration : filter, map, joiner;
import std.algorithm.searching : endsWith;
import std.regex;
import std.parallelism : parallel;
import std.array : join;
import std.process : execute;

import tagion.utils.JSONCommon;
import tagion.basic.Types : FileExtension;
import tagion.tools.revision;
import tagion.behaviour.BehaviourParser;
import tagion.behaviour.BehaviourIssue : Dlang, Markdown;

enum DOT='.'; /// File extension separator (Windows and Posix is a .)
enume ONE_ARGS_ONLY = 2; /// Opt-arg only accepts one argument

struct BehaviourOptions {
    string[] paths;
    string bdd_ext;
    // string dsrc_ext; // Extension
    string bdd_dext; // Extension
    string regex_inc;
    string regex_exc;
    string bdd_gen;
    string gen;
    string dfmt;
    string[] dfmt_flags;
    void setDefault() {
        gen = "gen";
        bdd_ext = FileExtension.markdown;
        //  dsrc_ext = "." ~ FileExtension.dsrc;
        bdd_gen = [gen, FileExtension.markdown].join(DOT);
        bdd_dext = [gen, FileExtension.dsrc].join(DOT);
        regex_inc =   `/testbench/`;
        const which_dfmt=execute(["which", "dfmt"]);
        if (which_dfmt.status is 0) {
            dfmt = which_dfmt.output;
            dfmt_flags=["-i"];
        }
    }
    mixin JSONCommon;
    mixin JSONConfig;
}


const(char[]) stripDot(const(char[]) ext) pure nothrow @nogc {
    if ((ext.length > 0) && (ext[0] == DOT)) {
        return ext[1..$];
    }
    return ext;
}

int parse_bdd(ref const(BehaviourOptions) opts) {
    const regex_include = regex(opts.regex_inc);
    const regex_exclude = regex(opts.regex_exc);
//    const do_format=
    auto bdd_files = opts.paths
        .map!(path => dirEntries(path, SpanMode.depth))
        .joiner
        .filter!(file => file.isFile)
        .filter!(file => file.name.extension.stripDot == opts.bdd_ext)
        .filter!(file => (opts.regex_inc.length is 0) || !file.name.matchFirst(regex_include).empty)
        .filter!(file => (opts.regex_exc.length is 0) || file.name.matchFirst(regex_exclude).empty);

    int result_errors; /// Error counter
    foreach (d; parallel(bdd_files)) {
        auto dsource = d.name.setExtension(FileExtension.dsrc);
        const bdd_gen = dsource.setExtension(opts.bdd_gen);
        if (dsource.exists) {
            dsource = dsource.setExtension(opts.bdd_dext);
        }
        writeln(d.name);
        writeln(dsource);
        writeln(bdd_gen);
        try {
            auto feature=parser(d.name);
            { // Generate d-source file
                auto fout = File(dsource, "w");
                scope(exit) {
                    fout.close;
                }
                auto dlang = Dlang(fout);
                dlang.issue(feature);
                if (opts.dfmt.length) {
                    execute(opts.dfmt ~ opts.dfmt_flags ~ dsource);
                }
            }
            { // Generate bdd-md file
                auto fout = File(bdd_gen, "w");
                scope(exit) {
                    fout.close;
                }
                auto markdown = Markdown(fout);
                markdown.issue(feature);
            }

        }
        catch (Exception e) {
            writeln(e.msg);
            result_errors++;
        }
    }
    return result_errors;
}

int main(string[] args) {
    BehaviourOptions options;
    immutable program = args[0];
    auto config_file = "behaviour.json";
    bool version_switch;
    bool overwrite_switch;

    if (config_file.exists) {
        options.load(config_file);
    }
    else {
        options.setDefault;
    }

    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        "version", "display the version", &version_switch,
        "I", "Include directory", &options.paths,
        std.getopt.config.bundling,
        "O", format("Write configure file %s", config_file), &overwrite_switch,
        "i|regex_inc", format("Include regex `%s`", options.regex_inc),
        &options.regex_inc,
        "x|regex_exc", format("Exclude regex `%s`", options.regex_exc),
        &options.regex_exc
    );

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    if (overwrite_switch) {
        if (args.length is ONE_ARGS_ONLY) {
            config_file = args[1];
        }
        options.save(config_file);
        writefln("Configure file written to %s", config_file);
        return 0;
    }

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
                    revision_text,
                    "Documentation: https://tagion.org/",
                    "",
                    "Usage:",
                    format("%s [<option>...]", program),
                    "",
                    "<option>:",

                    ].join("\n"),
                main_args.options);
        return 0;
    }

    auto result = parse_bdd(options);

    return result;
}
