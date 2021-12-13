#!/usr/bin/rdmd -g

//#!/usr/bin/env rdmd
module gits;

import std.stdio;
import std.process;
import std.file;
import std.string : lineSplitter, strip;

import std.algorithm.iteration : each, map, splitter;
import std.regex;
//import std.algorithm.iteration : chunkBy;
import std.range : chunks, generate, takeExactly;
import std.typecons : Yes, No;
//std.range.takeExactly
import std.random;
import std.path : buildPath;
import std.array : array;
import std.conv : octal;
import std.format;
import std.range.primitives : isInputRange;

enum REPOROOT="REPOROOT";

enum ENV="/usr/bin/env";

struct Git {
    const(string) reporoot;
    const(string[string]) gitmap;
    const(string) tmpdir;
//    tempDir
    this(string reporoot) {
        this.reporoot = reporoot;
        gitmap = get_submodules(reporoot);

        tmpdir=tempDir.buildPath(
            ".gits-" ~
            generate!(() => uniform('a', 'z'))
            .takeExactly(16)
            .array);
        tmpdir.mkdir;
    }

    version(none)
    ~this() {
        tmpdir.rmdir;
    }


    static const(string[string]) get_submodules(const(string) reporoot) {
        scope git_log=execute([
                "git", "submodule", "foreach", "--recursive",
                "pwd"],
            null, Config.init, uint.max,
            reporoot);
        string[string] result;
        enum regex_repo = regex(`\w+\s+'([^']+)`);
        git_log
            .output
            .lineSplitter
            .chunks(2)
            .each!((m) {
                    const match=m.front.matchFirst(regex_repo);
                    m.popFront;
                    result[match[1]] = m.front;
                    return Yes.each;
                });
        return result;
    }

    enum script_sh="temp.sh";
    enum git_alias_regex = regex(`alias\.(\w+)\s+(.*)`);


    string gitAlias(string name, string config_file=null) const {
        auto command = ["git",
            "--no-pager", "config"];
        if (config_file) {
            command~=["--file", config_file];
        }
        command~=["--get", format("alias.%s", name)];
        scope git_alias_log=execute(
            command,
            null, Config.init, uint.max,
            reporoot);
        //writefln("git_alias_log=%s", git_alias_log.output);
        return git_alias_log.output;
    }

    string gitAlias(Range)(const(string) name, Range config_files) if (isInputRange!Range) {
        string git_alias;
        foreach(conf; config_files) {
            git_alias = gitAlias(name, conf);
            if (!git_alias) {
                return git_alias;
            }
        }
        return git_alias;
    }

    string[string] gitAllAlias(string config_file=null) const {
        auto command = ["git",
            "--no-pager", "config"];
        if (config_file) {
            command~=["--file", config_file];
        }
        command~=["--get-regex", "alias"];
        scope git_alias_log=execute(
            command,
            null, Config.init, uint.max,
            reporoot);
        string[string] result;
        git_alias_log
            .output
            .lineSplitter
            .map!(a => a.matchFirst(git_alias_regex))
            .each!((m) {
                    result[m[1]]=m[2];
                    return Yes.each;
                });
        return result;
    }

    const(string) addAliasScript(const(string[string]) aliases) {
        const result=tmpdir.buildPath("add_alias.sh");
        auto fout=result.File("w");
        scope(exit) {
            result.setAttributes(octal!750);
            fout.close;
        }

        fout.writefln("#!%s bash", ENV);
        enum esc_regex=regex(`(\"|\#)`);
        string esc(Captures!(string) m) {
            return `\`~m.hit;
        }
        foreach(name, code; aliases) {
            const esc_code=code.replaceAll!esc(esc_regex);
            fout.writefln(`git config --local alias.%s "%s"`, name, esc_code);
        }
        return result;
        // return bout.toString.idup;
    }

    bool gitCommand(string git_cmd) {
        scope git_log=execute([
            "git",
            "--no-pager",
            "help",
            "-a"
                ],
            null, Config.init, uint.max,
            reporoot);
        const git_cmd_regex=regex(format(`^\s+(%s)`, git_cmd));
        bool found;
        git_log
            .output
            .lineSplitter
            .map!(a => a.matchFirst(git_cmd_regex))
            .each!((m) {
                    if (!m.empty) {
                        found=true;
                         return No.each;
                    }
                    return Yes.each;
                });
        return found;

    }

    void doAll(const(string[]) command) {
        void doit(const(string[]) cmds, string name, string path) {
//            writefln("cmds=%s", cmds);
            scope cmd_log=execute(
                cmds,
                null, Config.init, uint.max,
                path);
            if (cmd_log.output.strip.length) {
                writefln("Git '%s'", name);
                write(cmd_log.output);
            }
        }
        string[] cmds;
        const git_alias=gitAlias(command[0], [".gitconfig", null]);
        if (git_alias) {

            cmds~="git";
            cmds~=command;
        }
        else if (gitCommand(command[0])) {

            cmds~="git";
            cmds~=command;
        }
        else {
            cmds~=command; //.dup;
        }

        foreach(name, path; gitmap) {
            doit(cmds, name, path);
        }
        doit(cmds, reporoot, reporoot);

    }
}

int main(string[] args) {

    auto git =Git(environment.get(REPOROOT, getcwd));
    if (args.length >= 2) {
        git.doAll(args[1..$]); //, args[2..$]);
    }
    return 0;
}
