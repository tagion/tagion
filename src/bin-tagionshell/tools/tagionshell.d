module tagion.tools.tagionshell;

import tagion.tools.Basic;



mixin Main!(_main, "shell");


int _main(string[] args) {

    import std.stdio;

    writeln("hello world");


    return 0;
}
