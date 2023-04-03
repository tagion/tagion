/// Tool to generated behaviour driven code from markdown description 
module tagion.tools.collider;

/**
 * @brief tool generate d files from bdd md files and vice versa
 */

import std.algorithm.searching : canFind;
import std.getopt;
import std.stdio;
import std.format;
import std.path : extension, setExtension, dirName, buildPath;
import std.file : exists, dirEntries, SpanMode, readText, fwrite = write;
import std.string : join, strip, splitLines;
import std.algorithm.iteration : filter, map, joiner, fold, uniq, splitter, each;
import std.algorithm.sorting : sort;
import std.regex : regex, matchFirst;
import std.parallelism : parallel;
import std.array : join, split, array;
import std.process : execute, environment;
import std.range;
import std.typecons : Tuple;

import tagion.utils.JSONCommon;
import tagion.basic.Types : FileExtension, DOT;
import tagion.tools.revision : revision_text;
import tagion.behaviour.BehaviourParser;
import tagion.behaviour.BehaviourIssue : Dlang, DlangT, Markdown;
import tagion.behaviour.Emendation : emendation, suggestModuleName;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.Behaviour : TestCode, testCode, testColor, getBDDErrors;

import tagion.hibon.HiBONRecord : fwrite, fread;

import tagion.utils.Term;

enum ONE_ARGS_ONLY = 2;
enum DFMT_ENV = "DFMT"; /// Set the path and argument d-format including the flags
enum ICONV = "iconv"; /// Character format converter  

/** 
 * Option setting for the optarg and behaviour.json config file
 */
struct BehaviourOptions {
    /** Include paths for the BDD source files */
    string[] paths;
    /** BDD extension (default markdown .md) */
    string bdd_ext;
    /** Extension for d-source files (default .d) */
    string d_ext;
    /** Regex filter for the files to be incl */
    string regex_inc;
    /** Regex for the files to be excluded */
    string regex_exc;
    /** Extension for the generated BDD-files */
    string bdd_gen_ext;
    /** D source formater (default dfmt) */
    string dfmt;
    /** Command line flags for the dfmt */
    string[] dfmt_flags;

    /** Character converter (default iconv) */
    string iconv;
    /** Command line flags for the iconv */
    string[] iconv_flags;

    string importfile; /// Import file which are included into the generated skeleton
    bool verbose_switch;
    bool enable_package; /// This produce the package 
    /** 
     * Used to set default options if config file not provided
     */
    void setDefault() {
        const gen = "gen";
        bdd_ext = FileExtension.markdown;
        bdd_gen_ext = [gen, FileExtension.markdown].join(DOT);
        d_ext = [gen, FileExtension.dsrc].join(DOT);
        regex_inc = `/testbench/`;
        if (!(DFMT_ENV in environment)) {
            const which_dfmt = execute(["which", "dfmt"]);
            if (which_dfmt.status is 0) {
                dfmt = which_dfmt.output;
                dfmt_flags = ["-i"];
            }
        }
        const which_iconv = execute(["which", "iconv"]);
        iconv = which_iconv.output;
        iconv_flags = ["-t", "utf-8", "-f", "utf-8", "-c"];
    }

    mixin JSONCommon;
    mixin JSONConfig;
}

alias ModuleInfo = Tuple!(string, "name", string, "file"); /// Holds the filename and the module name for a d-module

/** 
 * Used to remove dot
 * @param ext - lines to remove dot
 * @return stripted
 */
const(char[]) stripDot(const(char[]) ext) pure nothrow @nogc {
    if ((ext.length > 0) && (ext[0] == DOT)) {
        return ext[1 .. $];
    }
    return ext;
}

/** 
 * Used to check valid filename
 * @param filename - filename to be checked
 * @return true if the file is not a generated or markdown
 */
bool checkValidFile(string file_name) {
    return !(canFind(file_name, ".gen") || !canFind(file_name, ".md"));
}

/** 
 * Parses markdown BDD and produce a new format markdown
* and a d-source skeleton
 * @param opts - options for behaviour
 * @return amount of erros in markdown files
 */
int parse_bdd(ref const(BehaviourOptions) opts) {
    const regex_include = regex(opts.regex_inc);
    const regex_exclude = regex(opts.regex_exc);
    alias DlangFile = DlangT!File;
    if (opts.importfile) {
        DlangFile.preparations = opts.importfile.readText.splitLines;
    }
    auto bdd_files = opts.paths
        .map!(path => dirEntries(path, SpanMode.depth))
        .joiner
        .filter!(file => file.isFile)
        .filter!(file => file.name.extension.stripDot == opts.bdd_ext)
        .filter!(file => (opts.regex_inc.length is 0) || !file.name.matchFirst(regex_include).empty)
        .filter!(file => (opts.regex_exc.length is 0) || file.name.matchFirst(regex_exclude).empty);
    string[] dfmt;

    if (opts.dfmt.length) {
        dfmt = opts.dfmt.strip ~ opts.dfmt_flags.dup;
    }
    else {
        dfmt = environment.get(DFMT_ENV, null).split.array.dup;
    }

    string[] iconv; /// Character convert used to remove illegal chars in files
    if (opts.iconv.length) {
        iconv = opts.iconv.strip ~ opts.iconv_flags.dup;
    }
    ModuleInfo[] list_of_modules;

    /* Error counter */
    int result_errors;
    foreach (file; bdd_files) {
        if (!checkValidFile(file)) {
            continue;
        }
        auto dsource = file.name.setExtension(FileExtension.dsrc);
        const bdd_gen = dsource.setExtension(opts.bdd_gen_ext);
        if (dsource.exists) {
            dsource = dsource.setExtension(opts.d_ext);
        }
        try {
            string[] errors; /// List of parse errors

            auto feature = parser(file.name, errors);
            feature.emendation(file.name.suggestModuleName(opts.paths));

            if (errors.length) {
                writefln("Amount of erros in %s: %s", file.name, errors.length);
                errors.join("\n").writeln;
                result_errors++;
                continue;
            }

            if (opts.enable_package && feature.info.name) {
                list_of_modules ~= ModuleInfo(feature.info.name, file.setExtension(
                        FileExtension.dsrc));
            }
            { // Generate d-source file
                auto fout = File(dsource, "w");
                if (opts.verbose_switch) {
                    writefln("dsource file %s", dsource);
                }
                auto dlang = Dlang(fout);
                dlang.issue(feature);
                fout.close;
                if (iconv.length) {
                    const exit_code = execute(iconv ~ dsource);
                    if (exit_code.status) {
                        writefln("Correction error %s", exit_code.output);
                    }
                    else {
                        dsource.fwrite(exit_code.output);
                    }
                }
                if (dfmt.length) {
                    const exit_code = execute(dfmt ~ dsource);
                    if (exit_code.status) {
                        writefln("Format error %s", exit_code.output);
                    }
                }
            }
            { // Generate bdd-md file
                auto fout = File(bdd_gen, "w");
                scope (exit) {
                    fout.close;
                }
                auto markdown = Markdown(fout);
                markdown.issue(feature);
            }
        }
        catch (Exception e) {
            writeln(e);
            result_errors++;
        }
    }
    list_of_modules.generate_packages;
    return result_errors;
}

enum package_filename = "package".setExtension(FileExtension.dsrc);
void generate_packages(const(ModuleInfo[]) list_of_modules) {
    auto module_paths = list_of_modules
        .map!(mod => mod.file.dirName) //.array
        .uniq;
    foreach (path; module_paths) {
        auto modules_in_the_same_package = list_of_modules
            .filter!(mod => mod.file.dirName == path);
        const package_path = buildPath(path, package_filename);
        auto fout = File(package_path, "w");
        scope (exit) {
            fout.close;
        }
        auto module_split = modules_in_the_same_package.front.name
            .splitter(DOT);

        const count_without_module_mame = module_split.walkLength - 1;

        fout.writefln(q{module %-(%s.%);},
            module_split.take(count_without_module_mame));

        fout.writeln;

        modules_in_the_same_package
            .map!(mod => mod.name.idup)
            .array
            .sort
            .each!(module_name => fout.writefln(q{public import %s=%s;},
                    module_name.split(DOT).tail(1).front, // Module identifier
                    module_name));
    }
}

int check_reports(string[] paths, const bool verbose) {

    bool show(const TestCode test_code) nothrow {
        return verbose || test_code == TestCode.error || test_code == TestCode.started;
    }

    void show_report(Args...)(const TestCode test_code, string fmt, Args args) {
        static if (Args.length is 0) {
            const text = fmt;
        }
        else {
            const text = format(fmt, args);
        }
        writefln("%s%s%s", testColor(test_code), text, RESET);
    }

    void report(Args...)(const TestCode test_code, string fmt, Args args) {
        if (show(test_code)) {
            show_report(test_code, fmt, args);
        }
    }

    struct ReportCount {
        uint passed;
        uint errors;
        uint started;
        uint total;
        void update(const TestCode test_code) nothrow pure {
            final switch (test_code) {
            case TestCode.none:
                break;
            case TestCode.passed:
                passed++;
                break;
            case TestCode.error:
                errors++;
                break;
            case TestCode.started:
                started++;

            }
            total++;
        }

        TestCode testCode() nothrow pure const {
            if (passed == total) {
                return TestCode.passed;
            }
            if (errors > 0) {
                return TestCode.error;
            }
            if (started > 0) {
                return TestCode.started;
            }
            return TestCode.none;
        }

        int result() nothrow pure const {
            final switch (testCode) {
            case TestCode.none:
                return 1;
            case TestCode.error:
                return cast(int) errors;
            case TestCode.started:
                return -cast(int)(started);
            case TestCode.passed:
                return 0;
            }
            assert(0);
        }

        void report(string text) {
            const test_code = testCode;
            if (test_code == TestCode.passed) {
                show_report(test_code, "%d test passed BDD-tests", total);
            }
            else {
                writef("%s%s%s: ", BLUE, text, RESET);
                show_report(test_code, " passed %2$s/%1$s, failed %3$s/%1$s, started %4$s/%1$s",
                    total, passed, errors, started);
            }
        }

    }

    ReportCount feature_count;
    ReportCount scenario_count;
    int result;
    foreach (path; paths) {
        foreach (string report_file; dirEntries(path, "*.hibon", SpanMode.breadth)
            .filter!(f => f.isFile)) {
            try {
                const feature_group = report_file.fread!FeatureGroup;
                const feature_test_code = testCode(feature_group);
                feature_count.update(feature_test_code);
                if (show(feature_test_code)) {
                    writefln("Report file %s", report_file);
                }

                report(feature_test_code, feature_group.info.property.description);
                const show_scenario = feature_test_code == TestCode.error
                    || feature_test_code == TestCode.started;
                foreach (scenario_group; feature_group.scenarios) {
                    const scenario_test_code = testCode(scenario_group);
                    scenario_count.update(scenario_test_code);
                    if (show_scenario) {
                        report(scenario_test_code, "\t%s", scenario_group.info.property
                                .description);
                        foreach (err; getBDDErrors(scenario_group)) {
                            report(scenario_test_code, "\t\t%s", err.msg);
                        }
                    }
                }
            }
            catch (Exception e) {
                error("Error: %s in handling report %s", e.msg, report_file);
            }
        }
    }

    feature_count.report("Features ");
    if (feature_count.testCode !is TestCode.passed) {
        scenario_count.report("Scenarios");
    }
    return feature_count.result;
}

void error(Args...)(string fmt, Args args) {
    stderr.writefln("%s%s%s", RED, format(fmt, args), RESET);
}

int main(string[] args) {
    BehaviourOptions options;
    immutable program = args[0]; /** file for configurations */
    auto config_file = "behaviour.json"; /** flag for print current version of behaviour */
    bool version_switch; /** flag for overwrite config file */
    bool overwrite_switch; /** falg for to enable report checks */
    bool Check_reports_switch;
    bool check_reports_switch; /** verbose switch */
    try {
        if (config_file.exists) {
            options.load(config_file);
        }
        else {
            options.setDefault;
        }
        auto main_args = getopt(args, std.getopt.config.caseSensitive,
            "version", "display the version", &version_switch,
            "I", "Include directory", &options.paths, std.getopt.config.bundling,
            "O", format("Write configure file %s", config_file), &overwrite_switch,
            "r|regex_inc", format(`Include regex Default:"%s"`, options.regex_inc), &options.regex_inc,
            "x|regex_exc", format(`Exclude regex Default:"%s"`, options.regex_exc), &options.regex_exc,
            "i|import", format(`Set include file Default:"%s"`, options.importfile), &options
                .importfile,
            "p|package", "Generates D package to the source files", &options
                .enable_package,
            "c|check", "Check the bdd reports in give list of directories", &check_reports_switch,
            "C", "Same as check but the program will return a nozero exit-code if the check fails", &Check_reports_switch,
            "v|verbose", "Enable verbose print-out", &options.verbose_switch,
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
            defaultGetoptPrinter([
                revision_text,
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...]", program),
                "",
                "<option>:",
            ].join("\n"), main_args.options);
            return 0;
        }
        check_reports_switch = Check_reports_switch || check_reports_switch;
        if (check_reports_switch) {
            const ret = check_reports(args[1 .. $], options.verbose_switch);
            if (ret) {
                writeln("Test result failed!");
            }
            else {
                writeln("Test result success!");
            }
            return (Check_reports_switch) ? ret : 0;
        }
        return parse_bdd(options);
    }
    catch (Exception e) {
        error("Error: %s", e.msg);
    }
    return 1;
}
