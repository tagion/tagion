/// Tool to create report files from collider hibon files
module tagion.tools.collider.reporter;

/**
 * @brief tool generate d files from bdd md files and vice versa
 */
import tagion.tools.Basic : Main;

import tagion.hibon.HiBONRecord : isRecord;
import tagion.hibon.HiBONFile : fwrite, fread;
import tagion.hibon.HiBONJSON;
import tagion.hibon.Document : Document;
import tagion.tools.revision : revision_text;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourResult;
import std.file;
import std.getopt;
import std.format;
import std.string;
import std.algorithm.iteration;
import std.algorithm.sorting;
import std.stdio;
import std.array;
import std.traits;
import std.path;

mixin Main!(_main);

enum OutputFormat {
    github = "github",
    markdown = "markdown",
}

int _main(string[] args) {
    immutable program = args[0];
    string output;
    OutputFormat format_style = OutputFormat.markdown;

    auto main_args = getopt(args,
            "o|output", "output file", &output,
            "f|format", format("Format style, one of %s", [EnumMembers!OutputFormat]), &format_style,
    );

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

    string log_dir = ".";
    if (args.length == 2) {
        log_dir = args[1];
    }
    if (!output) {
        output = "/dev/stdout";
    }

    if (!log_dir.exists || !log_dir.isDir) {
        stderr.writeln("Log directory does not exist");
        return 1;
    }

    auto result_files = dirEntries(log_dir, SpanMode.depth).filter!(dirEntry => dirEntry.name.endsWith(".hibon"))
        .map!(dirEntry => dirEntry.name)
        .array
        .sort;

    if (result_files.length == 0) {
        stderr.writeln("No hibon result files found");
    }

    FeatureGroup[] featuregroups;
    foreach (result; result_files) {
        featuregroups ~= fread!FeatureGroup(result);
    }

    auto outstring = appender!string;
    if (format_style == OutputFormat.github) {
        foreach(fg; featuregroups) {
            foreach (scenario; fg.scenarios) {
                void printErrors(Info)(Info info) {
                    if (info.result.isRecord!BehaviourError) {
                        auto bdd_err = BehaviourError(info.result);
                        outstring.put(
                            "::error file=%s,line=%s,title=BDD error::%s\n"
                                .format(
                                    bdd_err.file.relativePath,
                                    bdd_err.line,
                                    bdd_err.msg,
                                )
                        );
                        outstring.put("::group::BDD error\n");
                        foreach(l; bdd_err.trace) {
                            outstring.put(l ~ '\n');
                        }
                        outstring.put("::endgroup::\n");
                    }
                }
                foreach(info; scenario.given.infos) {
                    printErrors(info);
                }
                foreach(info; scenario.when.infos) {
                    printErrors(info);
                }
                foreach(info; scenario.then.infos) {
                    printErrors(info);
                }
                foreach(info; scenario.but.infos) {
                    printErrors(info);
                }
            }
        }
    }
    else {
        foreach (fg; featuregroups) {
            outstring.put(fg.toMd);
        }
    }

    File(output, "w").write(outstring.data);

    return 0;
}

alias MdString = string;

/// Gh flavor markdown
MdString toMd(FeatureGroup fg) {
    auto result_md = appender!string;
    string result_type() {
        if (fg.info.result.isRecord!Result) {
            return "✔️ ";
        }
        else if (fg.info.result.isRecord!BehaviourError) {
            return "❌";
        }
        else {
            return "❓";
        }
    }

    uint successful = 0;
    foreach (scenario; fg.scenarios) {
        if (scenario.info.result.isRecord!Result) {
            successful += 1;
        }
    }
    const summary = format("<summary> %s (%s/%s) %s </summary>\n\n", result_type, successful, fg.scenarios.length, fg
            .info.name);

    // result_md.put(format("%s\n\n", result_type));

    result_md.put("<details>");
    result_md.put(summary);
    result_md.put("```json\n");
    result_md.put(format("%s\n", fg.toPretty));
    result_md.put("```\n\n");
    result_md.put("</details><br>\n\n");
    return result_md[];
}
