module tagion.tools.Basic;

import std.typecons : Tuple;
import std.path : dirName, buildPath, baseName;
import std.file : exists, symlink, remove, thisExePath,
    getLinkAttributes, attrIsSymlink, FileException;

import std.stdio;

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
        writefln("%s -> %s", toolname, thisExePath);
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
