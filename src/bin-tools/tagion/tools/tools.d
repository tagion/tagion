module tagion.tools.tools;

version = TAGION_TOOLS;

import std.meta;
import std.traits;
import std.range : tail;
import std.algorithm.iteration : map;
import std.array : split;
import std.format;
import std.stdio;
import std.path : baseName;
import std.typecons : Tuple;


int main(string[] args) {
    import tagionwave = tagion.tools.tagionwave;
    import dartutil = tagion.tools.dartutil;
    import hibonutil = tagion.tools.hibonutil;
    import tagionwallet = tagion.tools.tagionwallet;

    alias alltools = AliasSeq!(tagionwave, dartutil, hibonutil, tagionwallet);
    enum toolName(alias tool)=moduleName!tool.split(".").tail(1)[0];

    enum toolnames=staticMap!(toolName, alltools);

    auto tool=args[0].baseName;

    alias Result=Tuple!(int, "exit_code", bool, "executed");
    Result do_main(string tool, string[] args) {
    SelectTool:
        switch (tool) {
            static foreach(toolname; toolnames) {{
                    case toolname:
                        enum code =format(q{return Result(%s._main(args), true);}, toolname);
                        // pragma(msg, code);
                        mixin(code);
                        break SelectTool;
                }}
        default:
            return Result(0, false);
        }
        assert(0);
    }
    auto result=do_main(tool, args);
    if (!result.executed && args.length > 1) {
        tool=args[1];
        result=do_main(tool, args[1..$]);
    }
    if (!result.executed) {
        stderr.writefln("Invalid tool %s available %-(%s, %)", tool, [toolnames]);
        return 1;
    }
    return result.exit_code;
}
