module tagion.testbench.testbench;

import std.meta;

import tagion.tools.OneMain;

int main(string[] args) {
    import hirpcclient = tagion.testbench.hirpcclient;
    import hirpcserver = tagion.testbench.hirpcserver;

    alias alltools = AliasSeq!(hirpcclient, hirpcserver);
    mixin doOneMain!(alltools);
    return do_main(args);
}
