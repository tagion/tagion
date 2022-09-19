/// \file behaviour.d
module tagion.tools.behaviour;

/**
 * @brief tool generate d files from bdd md files and vice versa
 */

import std.algorithm.searching;
import std.getopt;
import std.stdio;
import std.format;
import std.path : extension, setExtension, stripExtension, absolutePath, pathSplitter;
import std.file : exists, dirEntries, SpanMode;
import std.string : join, splitLines, strip;
import std.algorithm.iteration : filter, map, joiner;
import std.algorithm.searching : endsWith;
import std.algorithm.comparison : equal;
import std.range.primitives :walkLength;
import std.range : take, drop;
import std.regex;
import std.parallelism : parallel;
import std.array : join;
import std.process : execute;
import tagion.utils.JSONCommon;
import tagion.basic.Types : FileExtension;
import tagion.tools.revision;
import tagion.behaviour.BehaviourParser;
import tagion.behaviour.BehaviourIssue : Dlang, Markdown;
import tagion.behaviour.Emendation : emendation, suggestModuleName;

/* Opt-arg only accepts one argument */
enum ONE_ARGS_ONLY = 2;

/** 
 * Option setting for the optarg and behaviour.json config file
 */
struct BehaviourOptions {
    /* Include paths for the BDD source files */
    string[] paths;
    /* BDD extension (default markdown .md) */
    string bdd_ext;
    /* Extension for d-source files (default .d) */
    string d_ext;
    /* Regex filter for the files to be incl */
    string regex_inc;
    /* Regex for the files to be excluded */
    string regex_exc;
    /* Extension for the generated BDD-files */
    string bdd_gen_ext;
    /* D source formater (default dfmt) */
    string dfmt;
    /* Command line flags for the dfmt */
    string[] dfmt_flags;

    /** 
     * Used to set default options if config file not provided
     */
    void setDefault() {
        const gen = "gen";
        bdd_ext = FileExtension.markdown;
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

/** 
 * Used to remove dot
 * @param ext - lines to remove dot
 */
const(char[]) stripDot(const(char[]) ext) pure nothrow @nogc {
    if ((ext.length > 0) && (ext[0] == DOT)) {
        return ext[1..$];
    }
    return ext;
}

/** 
 * Params:
 *   filename = filename to be checked
 * Returns: true if the file is not a generated or markdown
 */
bool checkValidFile(string file_name) {
    return !(canFind(file_name, ".gen") || !canFind(file_name, ".md"));
}

/** 
 * Used to remove dot
 * @param opts - options for behaviour
 * @return amount of erros in md files
 */
int parse_bdd(ref const(BehaviourOptions) opts) {
    const regex_include = regex(opts.regex_inc);
    const regex_exclude = regex(opts.regex_exc);
    auto bdd_files = opts.paths
        .map!(path => dirEntries(path, SpanMode.depth))
        .joiner
        .filter!(file => file.isFile)
        .filter!(file => file.name.extension.stripDot == opts.bdd_ext)
        .filter!(file => (opts.regex_inc.length is 0) || !file.name.matchFirst(regex_include).empty)
        .filter!(file => (opts.regex_exc.length is 0) || file.name.matchFirst(regex_exclude).empty);

    /* Error counter */
    int result_errors;
    foreach (file; bdd_files) {
        if(!checkValidFile(file))
        {
            continue;
        }
        auto dsource = file.name.setExtension(FileExtension.dsrc);
        const bdd_gen = dsource.setExtension(opts.bdd_gen_ext);
        if (dsource.exists) {
            dsource = dsource.setExtension(opts.d_ext);
        }
        try {
            string[] errors;

            auto feature=parser(file.name, errors);
			feature.emendation(file.name.suggestModuleName(opts.paths));

            if (errors.length) {
                writefln("Amount of erros in %s: %s", file.name, errors.length);
                errors.join("\n").writeln;
                result_errors++;
                continue;
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
    /** file for configurations */
    auto config_file = "behaviour.json";
    /** flag for print current version of behaviour */
    bool version_switch;
    /** flag for overwrite config file */
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
//    writeln(result);
    return result;
}
