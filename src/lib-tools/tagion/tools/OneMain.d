module tagion.tools.OneMain;

import std.typecons : Tuple;

alias Result = Tuple!(int, "exit_code", bool, "executed");
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
            return Result(0, false);
        }
        assert(0);
    }

    enum alternative(alias mod) = mod.alternative_name;
    enum notNull(string name) = name !is null;
    /* 
    * Lists all the toolnames inclusive the alternative name as a alias-sequency
    */
    enum toolnames = [
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
    bool onetool_main(string[] args) {
        immutable program = args[0];
        bool version_switch;
        bool link_switch;
        try {
            auto main_args = getopt(args,
                    std.getopt.config.caseSensitive,
                    "version", "display the version", &version_switch,
                    std.getopt.config.bundling,
                    "Q|link", "Creates soft links all the link", &link_switch,
            );

            if (version_switch) {
                revision_text.writeln;
                return false;
            }

            if (link_switch) {
                return false;
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
                return false;
            }
        }
        catch (GetOptException e) {
            if (args.length > 0) {
                return true;
            }
            stderr.writeln(e.msg);
            return false;
        }
        return true;
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
            if (onetool_main(args)) {
                stderr.writefln("Invalid tool %s, available tools are %-(%s, %)", tool, toolnames);
                return 1;
            }
        }

        return result.exit_code;
    }
}
