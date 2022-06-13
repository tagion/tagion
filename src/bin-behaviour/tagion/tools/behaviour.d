module tagion.tools.behaviour;

import std.getopt;
import std.stdio;

mixin Main!_main;

struct BehaviourOptions {
    string[] paths;
    void setDefault() pure nothrow {
    }
    mixin JSONCommon;
    mixin JSONConfig;
}

int main(string[] args) {
    Options options;
    immutable program = args[0];
    auto config_file = "behaviour.json";
    bool version_switch;

    if (config_file.exists) {
        options.load(config_file);
    }
    else {
        options.setDefault;
    }

    auto main_args = getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.bundling,
        "version", "display the version", &version_switch,
        "O", "Write ", &options,
        "dartfilename|d", format("Sets the dartfile: default %s", dartfilename), &dartfilename,
    );

    if (version_switch) {
        // writefln("version %s", REVNO);
        // writefln("Git handle %s", HASH);
        return 0;
    }

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
            // format("%s version %s", program, REVNO),
            "Documentation: https://tagion.org/",
            "",
            "Usage:",
            format("%s <command> [<option>...]", program),
            "",
            "Where:",
            "<command>           one of [--read, --rim, --modify, --rpc]",
            "",

            "<option>:",

        ].join("\n"),
        main_args.options);
        return 0;
    }


    return 0;
}
