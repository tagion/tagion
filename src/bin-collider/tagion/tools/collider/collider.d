/// Tool to generated behaviour driven code from markdown description 
module tagion.tools.collider.collider;

/**
 * @brief tool generate d files from bdd md files and vice versa
*/

import std.algorithm.iteration : each, filter, fold, joiner, map, splitter, uniq;
import std.algorithm.searching : canFind;
import std.algorithm.sorting : sort;
import std.array : array, join, split;
import std.file : SpanMode, dirEntries, exists, readText, fwrite = write;
import std.format;
import std.getopt;
import std.parallelism : parallel;
import std.path : buildPath, dirName, extension, setExtension;
import std.process : environment, execute;
import std.range;
import std.regex : matchFirst, regex;
import std.stdio;
import std.string : join, splitLines, strip;
import std.typecons : Tuple;
import tagion.basic.Types : DOT, FileExtension, hasExtension;
import tagion.behaviour.Behaviour : TestCode, getBDDErrors, testCode, testColor;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourIssue : Dlang, DlangT, Markdown;
import tagion.behaviour.BehaviourParser;
import tagion.behaviour.Emendation : emendation, suggestModuleName;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.tools.Basic;
import tagion.tools.collider.BehaviourOptions;
import tagion.tools.collider.schedule;
import tagion.tools.revision : revision_text;
import tagion.utils.Term;

//import shitty=tagion.tools.collider.shitty;

alias ModuleInfo = Tuple!(string, "name", string, "file"); /// Holds the filename and the module name for a d-module

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
        .filter!(file => file.name.hasExtension(opts.bdd_ext))
        .filter!(file => (opts.regex_inc.length is 0) || !file.name.matchFirst(regex_include).empty)
        .filter!(file => (opts.regex_exc.length is 0) || file.name.matchFirst(regex_exclude).empty)
        .array;
    string[] dfmt;

    verbose("%-(BDD: %s\n%)", bdd_files);
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
                verbose("SRC: %s", dsource);
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
            .each!(module_name => fout.writefln(q{public import %s = %s;},
                    module_name.split(DOT).tail(1).front, // Module identifier
                    module_name));
    }
}

int check_reports(string[] paths) {

    bool show(const TestCode test_code) nothrow {
        return verbose_switch || test_code == TestCode.error || test_code == TestCode.started;
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

    struct TraceCount {
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

    TraceCount feature_count;
    TraceCount scenario_count;
    int result;
    foreach (path; paths) {
        foreach (string report_file; dirEntries(path, "*.hibon", SpanMode.breadth)
                .filter!(f => f.isFile)) {
            try {
                const feature_group = report_file.fread!FeatureGroup;
                const feature_test_code = testCode(feature_group);
                feature_count.update(feature_test_code);
                if (show(feature_test_code)) {
                    writefln("Trace file %s", report_file);
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

SubTools sub_tools;
static this() {
    import reporter = tagion.tools.collider.reporter;

    sub_tools["reporter"] = &reporter._main;
}

int main(string[] args) {
    BehaviourOptions options;
    immutable program = args[0]; /** file for configurations */
    auto config_file = "collider".setExtension(FileExtension.json); /** flag for print current version of behaviour */
    bool version_switch; /** flag for overwrite config file */
    bool overwrite_switch; /** falg for to enable report checks */
    bool Check_reports_switch;
    bool check_reports_switch;
    //    string[] stages;
    options.schedule_file = "collider_schedule".setExtension(FileExtension.json);

    string[] run_stages;
    uint schedule_jobs = 0;
    bool schedule_rewrite;
    bool schedule_write_proto;

    string testbench = "testbench";
    bool force_switch;
    // int function(string[])[string] sub_tools;
    //  sub_tools["shitty"] = &shitty._main;
    try {
        if (config_file.exists) {
            options.load(config_file);
        }
        else {
            options.setDefault;
        }
        const Result result = subTool(sub_tools, args);
        if (result.executed) {
            return result.exit_code;
        }
        auto main_args = getopt(args, std.getopt.config.caseSensitive,
                "version", "display the version", &version_switch,
                "I", "Include directory", &options.paths, std.getopt.config.bundling,
                "O", format("Write configure file '%s'", config_file), &overwrite_switch,
                "R|regex_inc", format(`Include regex Default:"%s"`, options.regex_inc), &options.regex_inc,
                "X|regex_exc", format(`Exclude regex Default:"%s"`, options.regex_exc), &options.regex_exc,
                "i|import", format(`Set include file Default:"%s"`, options.importfile), &options
                .importfile,
                "p|package", "Generates D package to the source files", &options
                .enable_package,
                "c|check", "Check the bdd reports in give list of directories", &check_reports_switch,
                "C", "Same as check but the program will return a nozero exit-code if the check fails", &Check_reports_switch,
                "s|schedule", format(
                    "Execution schedule Default: '%s'", options.schedule_file), &options.schedule_file,
                "r|run", "Runs the test in the schedule", &run_stages,
                "S", "Rewrite the schedule file", &schedule_rewrite,
                "j|jobs", format(
                "Sets number jobs to run simultaneously (0 == max) Default: %d", schedule_jobs), &schedule_jobs,
                "b|bin", format("Testbench program Default: '%s'", testbench), &testbench,
                "P|proto", "Writes sample schedule file", &schedule_write_proto,
                "f|force", "Force a symbolic link to be created", &force_switch,
                "v|verbose", "Enable verbose print-out", &__verbose_switch,
                "n|dry", "Shows the parameter for a schedule run (dry-run)", &__dry_switch,
                "silent", "Don't show progess", &options.silent,
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
                "# Sub-tools",
                format("%s %-(%s|%) [<options>...]", program, sub_tools.keys),
                "",
                "<option>:",
            ].join("\n"), main_args.options);
            return 0;
        }

        if (force_switch) {
            forceSymLink(sub_tools);
        }

        if (schedule_write_proto) {
            Schedule schedule;
            auto run_unit = RunUnit(["example"], ["WORKDIR": "$(HOME)/work"], ["-f$WORKDIR"], 0.0);

            schedule.units["collider_test"] = run_unit;
            schedule.save(options.schedule_file);
            return 0;
        }

        if (run_stages) {
            import core.cpuid : coresPerCPU;

            Schedule schedule;
            schedule.load(options.schedule_file);
            schedule_jobs = (schedule_jobs == 0) ? coresPerCPU : schedule_jobs;
            auto schedule_runner = ScheduleRunner(schedule, run_stages, schedule_jobs, options);
            schedule_runner.run([testbench]);
            if (schedule_rewrite) {
                schedule.save(options.schedule_file);
            }
            //   Check_reports_switch = true;
        }

        check_reports_switch = Check_reports_switch || check_reports_switch;
        if (check_reports_switch) {
            const ret = check_reports(args[1 .. $]);
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
        error(e);
        return 1;
    }
    return 0;
}
