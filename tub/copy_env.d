#!/usr/bin/env rdmd

import std.stdio;
import std.file;
import std.algorithm.iteration : each, filter, map;
import std.regex;
import std.format;
import std.getopt;
import std.array : join;

int main(string[] args) {
    immutable program = "copy_env";
    immutable REVNO = "0.0";
    string enable_name = "ENABLED";
    string from_regex_text = "ANDROID_";
    string to_name = "CROSS_";
    string target_name = "android-target";

    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "r|regex", format(
                "Sets for the filter and name to be changed (Default %s)", from_regex_text), &from_regex_text,
                "w|name", format("Sets the replace name (Default %s)", to_name), &to_name,
                "t|target", format("Sets the target name (Default %s)", target_name), &target_name,

                "e|enable", format("Sets the target name (Default %s)", enable_name), &enable_name,

        );
        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                    [
                format("%s version %s", program, REVNO),
                "Documentation: https://tagion.org/",
                "Utility used to do added target-specific environment in make format ",
                "Usage:",
                format("env | %s [<option>...] ", program),
                "",
                "<option>:",
            ].join("\n"),
            main_args.options);
            return 0;
        }
        const from_regex = regex(from_regex_text);

        writefln("%s=1", enable_name);
        stdin.byLine
            .filter!((a) => !a.matchFirst(from_regex).empty)
            .map!((a) => a.replaceFirst(from_regex, to_name))
            .map!((a) => format!"%s: %s"(target_name, a))
            .each!writeln;
    }
    catch (Exception e) {
        stderr.writeln("%s", e);
        return 1;
    }

    return 0;
}
