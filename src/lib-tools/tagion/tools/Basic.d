module tagion.tools.Basic;

import std.path : baseName, buildPath, dirName;
import std.typecons : Tuple;
import std.file : exists, symlink, remove, thisExePath,
    getLinkAttributes, attrIsSymlink, FileException;

import std.stdio;
import tagion.utils.Term;

__gshared static bool __verbose_switch;
__gshared static bool __dry_switch;
__gshared static File vout;
//static uint verbose_mask;

shared static this() {
    vout = stdout;
}

@trusted
bool verbose_switch() nothrow @nogc {
    return __verbose_switch;
}

@trusted
bool dry_switch() nothrow @nogc {
    return __dry_switch;
}

@trusted
private void __verbosef(Args...)(string fmt, lazy Args args) {
    vout.writef(fmt, args);
}

@trusted
private void __verbose(Args...)(string fmt, lazy Args args) {
    vout.writefln(fmt, args);
}

@safe
void verbose(Args...)(string fmt, lazy Args args) {
    if (verbose_switch) {
        __verbose(fmt, args);
    }
}

@trusted
void noboseln(Args...)(string fmt, lazy Args args) {
    if (!verbose_switch) {
        __verbose(fmt, args);
        stdout.flush;
    }
}

@trusted
void nobose(Args...)(string fmt, lazy Args args) {
    if (!verbose_switch) {
        __verbosef(fmt, args);
        stdout.flush;
    }
}

@trusted
void error(const Exception e) {
    error(e.msg);
    if (verbose_switch) {
        stderr.writefln("%s", e);
    }
}

void error(Args...)(string fmt, lazy Args args) @trusted {
    import std.format;

    stderr.writefln("%sError: %s%s", RED, format(fmt, args), RESET);
}

void warn(Args...)(string fmt, lazy Args args) @trusted {
    import std.format;

    vout.writefln("%s%s%s", YELLOW, format(fmt, args), RESET);
}

void info(Args...)(string fmt, lazy Args args) @trusted {
    import std.format;

    vout.writefln("%s%s%s", BLUE, format(fmt, args), RESET);
}

void good(Args...)(string fmt, lazy Args args) @trusted {
    import std.format;

    vout.writefln("%s%s%s", GREEN, format(fmt, args), RESET);
}

alias SubTools = int function(string[])[string];
Result subTool(const SubTools sub_tools, string[] args, const size_t index = 0) {
    if (args[index].baseName in sub_tools) {
        return Result(sub_tools[args[index].baseName](args[index .. $]), true);
    }
    if (index < 1) {
        return subTool(sub_tools, args, index + 1);
    }
    return Result.init;
}

alias Result = Tuple!(int, "exit_code", bool, "executed");

int forceSymLink(const SubTools sub_tools) {
    foreach (toolname; sub_tools.keys) {
        const symlink_filename = thisExePath.dirName.buildPath(toolname);
        if (symlink_filename.exists) {
            if (symlink_filename.getLinkAttributes.attrIsSymlink) {
                symlink_filename.remove;
            }
            else {
                stderr.writefln("Error: %s is not a symbolic link", symlink_filename);
                return 1;
            }
        }
        __verbose("%s -> %s", toolname, thisExePath);
        symlink(thisExePath, symlink_filename);
    }
    return 0;
}

mixin template Main(alias _main, string name = null) {
    import std.traits : fullyQualifiedName;

    version (ONETOOL) {
        enum alternative_name = name;
        enum main_name = fullyQualifiedName!_main;
    }
    else {
        int main(string[] args) {
            return _main(args);
        }
    }
}
