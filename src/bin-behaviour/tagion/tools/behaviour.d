module tagion.tools.behaviour;

import std.getopt;
import std.stdio;
import std.format;
import std.path : extension, setExtension;
import std.file : exists, dirEntries, SpanMode;
import std.string : join, splitLines, strip;
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
enum ONE_ARGS_ONLY = 2; /// Opt-arg only accepts one argument

struct BehaviourOptions {
    string[] paths; /// Include paths for the BDD source files
    string bdd_ext; /// BDD extension (default markdown .md)
    // string dsrc_ext; // Extension
    string d_ext; /// Extension for d-source files (default .d)
    string regex_inc;  /// Regex filter for the files to be incl
    string regex_exc;  /// Regex for the files to be excluded
    string bdd_gen_ext;    /// Extension for the generated BDD-files
//    string gen;        /// Pre-extension for the generated files
    string dfmt; /// D source formater (default dfmt)
    string[] dfmt_flags; /// Command line flags for the dfmt
    void setDefault() {
        const gen = "gen";
        bdd_ext = FileExtension.markdown;
        //  dsrc_ext = "." ~ FileExtension.dsrc;
        bdd_gen_ext = [gen, FileExtension.markdown].join(DOT);
        d_ext = [gen, FileExtension.dsrc].join(DOT);
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

    int result_errors; /// Error counter'
LoopFiles:
    foreach (file; bdd_files) {
        auto dsource = file.name.setExtension(FileExtension.dsrc); // .d
        const bdd_gen = dsource.setExtension(opts.bdd_gen_ext);
        if (dsource.exists) {
            dsource = dsource.setExtension(opts.d_ext); // .gen.d
        }
        writeln(file.name);
        writeln(dsource);
        writeln(bdd_gen);
        try {
            string[] errors;
            auto feature=parser(file.name, errors);
            writefln("!!!!!!!!!!!!!!! %s", errors.length);
            if (errors.length) {
                errors.join("\n").writeln;
                result_errors++;
                break LoopFiles;
            }
            { // Generate d-source file
                auto fout = File(dsource, "w");
                writefln("dsource file %s", dsource);
                scope(exit) {
                    fout.close;
                }
                auto dlang = Dlang(fout);
                dlang.issue(feature);
                if (opts.dfmt.length) {
                    writefln("%s", opts.dfmt.strip ~ opts.dfmt_flags ~ dsource);

                    execute(opts.dfmt.strip ~ opts.dfmt_flags ~ dsource);
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
            writeln(e);
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
