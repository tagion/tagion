@description("Visualize node to node communication")
module tagion.tools.nodeinterfaceutil;

import tagion.tools.Basic;

mixin Main!_main;

// The tool requires raylib
version(nodeinterfaceutil)
public import tagion.tools.nodeinterfaceutil.program;
else
int _main(string[] args) {
    import std.stdio;
    stderr.writefln("The tool '%s' is not supported in this build", args[0]);
    return 1;
}
