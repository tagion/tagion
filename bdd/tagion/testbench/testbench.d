module tagion.testbench.testbench;

import std.meta;

import tagion.tools.OneMain;

int main(string[] args) {
    import ssl_server = tagion.testbench.ssl_server;
    import bdd_mode1 = tagion.testbench.bdd_mode1;
    import bdd_services = tagion.testbench.bdd_services;
    import bdd_wallets = tagion.testbench.bdd_wallets;
    import ssl_echo_server = tagion.testbench.ssl_echo_server;

    alias alltools = AliasSeq!(
            ssl_server,
            bdd_mode1,
            bdd_services,
            bdd_wallets,
            ssl_echo_server,
    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
