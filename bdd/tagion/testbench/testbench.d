module tagion.testbench.testbench;

import std.meta;

import tagion.tools.OneMain;

int main(string[] args) {
    import hirpcclient = tagion.testbench.hirpcclient;
    import hirpcserver = tagion.testbench.hirpcserver;
    import bdd_mode1 = tagion.testbench.bdd_mode1;
    import bdd_services = tagion.testbench.bdd_services;
    import bdd_wallets = tagion.testbench.bdd_wallets;

    alias alltools = AliasSeq!(hirpcclient, hirpcserver, bdd_mode1, bdd_services, bdd_wallets,);
    mixin doOneMain!(alltools);
    return do_main(args);
}
