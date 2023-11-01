module tagion.tools.OneMain;

import std.typecons : Tuple;

string[] getMains(alias _package)() {
    return [__traits(allMembers, _package)];
}

private __gshared string __main_name;
string main_name() nothrow @nogc {
    return __main_name;
}

void main_name(string name) nothrow
in (__main_name.length is 0)
do {
    __main_name = name.idup;
}

mixin template doOneMain(alltools...) {
    import std.getopt;
    import std.stdio;
    import std.traits;
    import std.array : split;
    import std.range : tail;
    import std.format;
    import std.path : baseName;
    import tagion.tools.revision;
    import std.array : join;
    import std.algorithm.searching : canFind;
    import tagion.tools.Basic : Result;

    /*
    * Strips the non package name from a module-name
    */
    enum tailName(string name) = name.split(".").tail(1)[0];
    enum toolName(alias tool) = tailName!(moduleName!tool);

    /* 
     * 
     * Params:
     *   tool = The name of the tool to be called
     *   args = optarg for the tools
     * Returns: 
     *  The exit-code and if the tool has been executed
     */
    Result call_main(string tool, string[] args) {
        main_name = tool;
        writefln("MAIN %s", main_name);
    SelectTool:
        switch (tool) {
            static foreach (toolmod; alltools) {
                {
                    enum toolname = toolName!toolmod;
                    static if (toolmod.alternative_name) {
        case toolmod.alternative_name:
                    }
        case toolname:
                    enum code = format(q{return Result(%s.%s(args), true);},
                                toolname, tailName!(toolmod.main_name));
                    mixin(code);
                    break SelectTool;
                }
            }
        default:
            return Result(0, true);
        }
        assert(0);
    }

    enum alternative(alias mod) = mod.alternative_name;
    enum notNull(string name) = name !is null;
    /* 
    * Lists all the toolnames inclusive the alternative name as a alias-sequency
    */
    immutable toolnames = [
        AliasSeq!(
                staticMap!(toolName, alltools),
                Filter!(notNull, staticMap!(alternative, alltools))
        )
    ];

    /* 
     * Handles the arguments for the onetool main
     * Params:
     *   args = cli arguments
     * Returns: true if the onetool should continue to execute a tool
     */
    Result onetool_main(string[] args) {
        import std.file : exists, symlink, remove, thisExePath,
            getLinkAttributes, attrIsSymlink, FileException;
        import std.path;

        immutable program = args[0];
        bool version_switch;
        bool link_switch;
        bool force_switch;
        try {
            auto main_args = getopt(args,
                    std.getopt.config.caseSensitive,
                    "version", "display the version", &version_switch,
                    std.getopt.config.bundling,
                    "s|link", "Creates symbolic links all the tool", &link_switch,
                    "f|force", "Force a symbolic link to be created", &force_switch,
            );

            if (version_switch) {
                revision_text.writeln;
                return Result(0, true);
            }

            if (link_switch || force_switch) {
                foreach (toolname; toolnames) {
                    const symlink_filename = thisExePath.dirName.buildPath(toolname);
                    if (force_switch && symlink_filename.exists) {
                        if (symlink_filename.getLinkAttributes.attrIsSymlink) {
                            symlink_filename.remove;
                        }
                        else {
                            stderr.writefln("Error: %s is not a symbolic link", symlink_filename);
                            return Result(1, true);
                        }
                    }
                    writefln("%s -> %s", toolname, thisExePath);
                    symlink(thisExePath, symlink_filename);
                }
                return Result(0, true);
            }

            if (main_args.helpWanted) {
                defaultGetoptPrinter(
                        [
                        revision_text,
                        "Documentation: https://tagion.org/",
                        "Usage:",
                        format("%s <program> [<option>...]", program),
                        format("Tool programs %-(%s, %)", toolnames),
                        "",
                        "<option>:",

                        ].join("\n"),
                        main_args.options);
                return Result(0, true);
            }
        }
        catch (GetOptException e) {
            stderr.writefln("Error: %s", e.msg);
            return Result(1, true);
        }
        catch (FileException e) {
            stderr.writefln("Error: %s", e.msg);
            return Result(1, true);
        }
        return Result.init;
    }

    /* 
     * 
     * Params:
     *   args = optarg for the one tool
     *          args[0] or arg[1] is the name of tool 
     * Returns: exit-code for the program
     */
    int do_main(string[] args) {
        Result result;
        auto tool = args[0].baseName;
        if (toolnames.canFind(tool)) {
            result = call_main(tool, args);
        }
        else if (args.length > 1) {
            tool = args[1];
            if (toolnames.canFind(tool)) {
                result = call_main(tool, args[1 .. $]);
            }
        }
        if (!result.executed) {
            result = onetool_main(args);
            if (!result.executed) {
                stderr.writefln("Error: Invalid tool %s, available tools are %-(%s, %)", tool, toolnames);
            }
        }

        return result.exit_code;
    }
}
