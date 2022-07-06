module tagion.tools.behaviour;

import std.getopt;
import std.stdio;
import std.format;
import std.file : exists;
import std.string : join;
import std.string : splitLines;
import tagion.utils.JSONCommon;
import tagion.tools.revision;

struct BehaviourOptions {
    string[] paths;
    string bbd_filter;
    void setDefault() pure nothrow {
        bbd_filter = "*." ~ FileExtension.markdown;
    }
    mixin JSONCommon;
    mixin JSONConfig;
}

int parse_bdd(ref const(BehaviourOptions) opts) {

    auto bdd_files = dirEntries("", SpanMode.depth).filter!(f => f.name.endsWith(".d"));
foreach (d; dFiles)
    writeln(d.name);

    foreach (d; parallel(dFiles, 1)) {
//passes by 1 file to each thread
//{
        string cmd = "dmd -c "  ~ d.name;
        writeln(cmd);
        executeShell(cmd);
    }
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


    return 0;
}
