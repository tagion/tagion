#!/usr/bin/env rdmd
// # DMD
// #!/usr/bin/rdmd -g

module check_module;

import std.getopt;
import std.format;

import std.stdio;
import std.process;
import std.file : getcwd, exists;
import std.array : join;

import std.algorithm.iteration : map;
import std.algorithm.searching : any;
import std.string : splitLines;
import std.array : split;
import std.algorithm.searching : count;

import std.path : buildPath, buildNormalizedPath, setExtension, isRooted;

enum REPOROOT = "REPOROOT";
enum gitrepo = ".git";

string getRoot() {
    auto result = environment.get(REPOROOT, getcwd);
    while (!result.isRooted && result.buildPath(gitrepo).exists) {
        result = result.buildNormalizedPath("..");
    }
    return result;
}

int main(string[] args) {
    immutable command = ["git", "submodule", "status"];
    const program = "check_submodule";
    const REVNO = "0.0";
    try {
        auto main_args = getopt(args,
            std.getopt.config.caseSensitive,
            std.getopt.config.bundling,
        );
        if (main_args.helpWanted) {
            defaultGetoptPrinter(
                [
                    format("%s version %s", program, REVNO),
                    "Documentation: https://tagion.org/",
                    "If <workdir> is not giver as the first argument then $REPOROOT",
                    "and if this are not defined then the $PWD is used",
                    "Usage:",
                    format("%s [<workdir>] ", program),
                    "",
                    ].join("\n"),
                main_args.options);
            return 0;
        }

        immutable reporoot = (args.length == 2)?args[1]:getRoot;
        const git_command_log = execute(
            command,
            null, Config.init, uint.max,
            reporoot);
        auto git_status_list = git_command_log.output.splitLines.map!(a => a.split);
       if (git_status_list.any!q{a.length == 2}) {
           // Print the if any of the submodules hasn't been updated
           git_command_log.output.writeln;
       }
    }
    catch (Exception e) {
        stderr.writeln(e.msg);
        return 1;
    }
    return 0;
}
