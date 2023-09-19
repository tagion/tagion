module tagion.tools.tagionshell;

import std.array : join;
import std.getopt;
import std.file : exists;
import std.stdio;
import std.format;

import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.shell.shelloptions;




mixin Main!(_main, "shell");


int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    GetoptResult main_args;


    ShellOptions options;
    
    auto config_file = "shell.json";
    if (config_file.exists) {
        options.load(config_file);
    } else {
        options.setDefault;
    }
    
    try {
        main_args = getopt(args, std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
            "version", "display the version", &version_switch,
        );
    } catch (GetOptException e) {
        stderr.writeln(e.msg);
        return 1;
    }

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }
    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
            // format("%s version %s", program, REVNO),
            "Documentation: https://tagion.org/",
            "",
            "Usage:",
            format("%s [<option>...] <config.json> <files>", program),
            "",
            "<option>:",

        ].join("\n"),
                main_args.options);
        return 0;
    }

    return 0;
}
