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

import tagion.utils.JSONCommon;
import tagion.basic.Types : FileExtension;
import tagion.tools.revision;
import tagion.behaviour.BehaviourParser;

struct BehaviourOptions {
    string[] paths;
    string bdd_ext;
    // string dsrc_ext; // Extension
    string bdd_dext; // Extension
    string regex_inc;
    string regex_exc;

    void setDefault() pure nothrow {
        bdd_ext = FileExtension.markdown;
        //  dsrc_ext = "." ~ FileExtension.dsrc;
        bdd_dext = "gen." ~ FileExtension.dsrc;
        regex_inc =   `/testbench/`;
    }
    mixin JSONCommon;
    mixin JSONConfig;
}


const(char[]) stripDot(const(char[]) ext) pure nothrow @nogc {
    if ((ext.length > 0) && (ext[0] == '.')) {
        return ext[1..$];
    }
    return ext;
}

int parse_bdd(ref const(BehaviourOptions) opts) {

    auto bdd_files = dirEntries("", SpanMode.depth).filter!(f => f.name.endsWith(".d"));
    writefln("paths %s", opts.paths);
    writefln("opts=%s", opts);
    const regex_include = regex(opts.regex_inc);
    const regex_exclude = regex(opts.regex_exc);
    auto bdd_dirs = opts.paths
        .map!(path => dirEntries(path, SpanMode.depth))
        .joiner
        .filter!(f => f.isFile)
        .filter!(f => f.name.extension.stripDot == opts.bdd_ext)
        .filter!(f => (opts.regex_inc.length is 0) || !f.name.matchFirst(regex_include).empty)
        .filter!(f => (opts.regex_exc.length is 0) || f.name.matchFirst(regex_exclude).empty);

    // const x="xxx".matchFirst(regex_include).empty;
    int result;
    foreach (d; parallel(bdd_dirs)) {

        auto dsource = d.name.setExtension(FileExtension.dsrc);
//        const bdd_gen = dsource.setExtension
        if (dsource.exists) {
            dsource = dsource.setExtension(opts.bdd_dext);
        }
        writeln(d.name);
        writeln(dsource);
        try {
            const feature=parser(d.name);

        }
        catch (Exception e) {
            writeln(e.msg);
            result++;
        }
    }
//     foreach (d; parallel(dFiles, 1)) {
// //passes by 1 file to each thread
// //{
//         string cmd = "dmd -c "  ~ d.name;
//         writeln(cmd);
//         executeShell(cmd);
//     }
    return result;
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
    );

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }

    if (overwrite_switch) {
        if (args.length == 2) {
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
