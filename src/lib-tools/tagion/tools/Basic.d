module tagion.tools.Basic;

import std.path : baseName, buildPath, dirName;
import std.typecons : Tuple;
import std.file : exists, symlink, remove, thisExePath,
    getLinkAttributes, attrIsSymlink, FileException;

import std.stdio;
import std.algorithm;
import std.json;
import std.format;
import std.array;

import tagion.utils.Term;
import tagion.utils.JSONCommon;

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

    vout.writefln("%sWarning:%s%s", YELLOW, format(fmt, args), RESET);
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

/**
 * Set individual options in an options struct with runtime strings
 *
 * Params:
 *      local_options = A struct with a json common mixin
 *      override_options = a list of strings formattet a "some.member.key:value"
*/
void set_override_options(T)(ref T local_options, string[] override_options)
if(isJSONCommon!T) {
    JSONValue json = local_options.toJSON;

    void set_val(JSONValue j, string[] _key, string val) {
        if (_key.length == 1) {
            j[_key[0]] = val.toJSONType(j[_key[0]].type);
            return;
        }
        set_val(j[_key[0]], _key[1 .. $], val);
    }

    foreach (option; override_options) {
        const index = option.countUntil(":");
        assert(index > 0, format("Option '%s' invalid, missing key:value", option));
        string[] key = option[0 .. index].split(".");
        string value = option[index + 1 .. $];
        set_val(json, key, value);
    }
    // If options does not parse as a string then some types will not be interpreted correctly
    local_options.parseJSON(json.toString);
}
