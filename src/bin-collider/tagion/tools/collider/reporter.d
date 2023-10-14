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

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    string output;

    auto main_args = getopt(args,
            "o|output", "output file", &output,
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
        stderr.writeln("Output file is not specified");
        return 1;
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
    foreach (fg; featuregroups) {
        outstring.put(fg.toMd);
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
