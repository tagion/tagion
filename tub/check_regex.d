#!/usr/bin/env rdmd

import std.stdio;
import std.algorithm.iteration : each, filter;
import std.regex;
import std.format;
import std.getopt;
import std.array : join;

int main(string[] args) {
    immutable program = "check_regex";
    immutable REVNO = "0.0";
    string regex_text;

    try {
        auto main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "r|regex", "Regex to match", &regex_text,

        );
        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                    [
                format("%s version %s", program, REVNO),
                "Documentation: https://tagion.org/",
                "Untility to match a string (like sed) ",
                "Usage:",
                format("%s <list-of-words> -r <regex> ", program),
                "",
                "<option>:",
            ].join("\n"),
            main_args.options);
            return 0;
        }
        const match_regex = regex(regex_text);

        writefln("%-(%s %)",
                args
                .filter!((a) => !a.matchFirst(match_regex).empty));

    }
    catch (Exception e) {
        stderr.writeln("%s", e);
        return 1;
    }
    return 0;
}
