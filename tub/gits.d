#!/usr/bin/rdmd -g

//#!/usr/bin/env rdmd
module gits;

import std.stdio;
import std.process;
import std.file : mkdir, rmdir, getcwd, setAttributes, tempDir, readText, fwrite=write;
import std.string : lineSplitter, strip;

import std.algorithm.iteration : each, map, splitter;
import std.algorithm.searching : all;
import std.regex;
//import std.algorithm.iteration : chunkBy;
import std.range : chunks, generate, takeExactly;
import std.typecons : Yes, No;
//std.range.takeExactly
import std.random;
import std.path : buildPath, setExtension;
import std.array : array, join, array_replace=replace;
import std.conv : octal;
import std.format;
import std.range.primitives : isInputRange;
import core.thread : Thread;
import core.time;
//std.array.replace

enum REPOROOT="REPOROOT";

enum ENV="/usr/bin/env";

struct Git {
    const(string) reporoot;
    const(string[string]) gitmap;
    const(string) tmpdir;

    enum pause=200;
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

    enum log_ext="log";
    enum num_of_processes=8;
    void doAll(const(string[]) command) {
        struct PidInfo {
            Pid pid;
            string stdout_name;
            string stderr_name;
            File stdout;
            File stderr;
            void open(const(string) dir, const(string) filename) {
                stdout_name=dir.buildPath([filename, "stdin"].join("_"))
                    .setExtension(log_ext);
                stderr_name=dir.buildPath([filename, "strerr"].join("_"))
                    .setExtension(log_ext);
                stdout=File(stdout_name, "w");
                stderr=File(stderr_name, "w");
            }
            void close() {
                stdout.close;
                stderr.close;
            }
        }
        void doit(ref PidInfo pid_info, const(string[]) cmds, const(string) name, const(string) path) {
            pid_info.stdout.writefln("Git '%s'", name);
            pid_info.pid =spawnProcess(
                cmds,
                stdin,
                pid_info.stdout,
                pid_info.stderr,
                null,
                Config.init,
                path);
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

//        auto pids=new Pid[8];
        auto pid_infos = new PidInfo[num_of_processes];
        auto git_range=gitmap.byKeyValue;
        while (!git_range.empty) {
            if (pid_infos.all!((p) => p.pid.init !is Pid.init)) {
                Thread.sleep(pause.msecs);
            }
            foreach(ref pid_info; pid_infos) {
                if (pid_info.pid is Pid.init) {
                    pid_info.open(tmpdir, git_range.front.value.array_replace("/", "_"));
                    doit(pid_info, cmds, git_range.front.key, git_range.front.value);
                    git_range.popFront;
                }
                const state = tryWait(pid_info.pid);
                if (state.terminated) {
                    pid_info.close;
                    pid_info.stdout_name.readText.write;
                    pid_info.stderr_name.readText.write;
                    pid_info = PidInfo.init;
                }
            }
        }

        PidInfo root_pid_info;
        root_pid_info.open(tmpdir, "root");
        doit(root_pid_info, cmds, reporoot, reporoot);
        // writefln("MAIN ROOT !!!!!!!!!!!!!!!!");
        wait(root_pid_info.pid);
        root_pid_info.close;
        root_pid_info.stdout_name.readText.write;
        root_pid_info.stderr_name.readText.write;
    }
}

int main(string[] args) {

    auto git =Git(environment.get(REPOROOT, getcwd));
    if (args.length >= 2) {
        git.doAll(args[1..$]); //, args[2..$]);
    }
    return 0;
}
