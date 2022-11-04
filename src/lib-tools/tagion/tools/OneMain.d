module tagion.tools.OneMain;

import std.typecons : Tuple;

alias Result = Tuple!(int, "exit_code", bool, "executed");
mixin template doOneMain(alltools...) {
    import std.stdio;
    import std.traits;
    import std.array : split;
    import std.range : tail;
    import std.format;
    import std.path : baseName;

    enum toolName(alias tool) = moduleName!tool.split(".").tail(1)[0];

    Result call_main(string tool, string[] args) {

        //    const tool = args[0].baseName;
    SelectTool:
        switch (tool) {
            static foreach (toolmod; alltools) {
                {
                    enum toolname = toolName!toolmod;
                    static if (toolmod.alternative_name) {
        case toolmod.alternative_name:
                    }
        case toolname:
                    enum code = format(q{return Result(%s._main(args), true);}, toolname);
                    mixin(code);
                    break SelectTool;
                }
            }
        default:
            return Result(0, false);
        }
        assert(0);
    }

    int do_main(string[] args) {
        auto tool = args[0].baseName;
        auto result = call_main(tool, args);
        if (!result.executed && args.length > 1) {
            tool = args[1];
            result = call_main(tool, args[1 .. $]);
        }

        if (!result.executed) {
            enum alternative(alias mod) = mod.alternative_name;
            enum notNull(string name) = name !is null;
            enum toolnames = AliasSeq!(
                        staticMap!(toolName, alltools),
                        Filter!(notNull, staticMap!(alternative, alltools))
                );
            stderr.writefln("Invalid tool %s available %-(%s, %)", tool, [toolnames]);
            return 1;
        }
        return result.exit_code;
    }
}
