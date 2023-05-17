/// Tool to create report files from collider hibon files
module tagion.tools.collider.report;

/**
 * @brief tool generate d files from bdd md files and vice versa
 */
import tagion.tools.Basic;

import tagion.hibon.HiBONRecord : fwrite, fread, isRecord;
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

    auto result_files = dirEntries(log_dir, SpanMode.depth).filter!(dirEntry => dirEntry.name.endsWith(".hibon"))
        .map!(dirEntry => dirEntry.name);

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
            return format(":heavy_check_mark: %s", fg.info.name);
        }
        else if (fg.info.result.isRecord!BehaviourError) {
            return format(":x: %s", fg.info.name);
        }
        else {
            return format(":question: Unknown result type %s", fg.info.name);
        }
    }

    result_md.put(format("%s\n\n", result_type));

    result_md.put("<details>\n\n");
    result_md.put("```json\n");
    result_md.put(format("%s\n", fg.toPretty));
    result_md.put("```\n\n");
    result_md.put("</details><br>\n\n");
    return result_md[];
}
