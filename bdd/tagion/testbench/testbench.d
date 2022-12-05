module tagion.testbench.testbench;

import std.meta;

import tagion.tools.OneMain;

int main(string[] args) {
    import sslclient = tagion.testbench.sslclient;
    import sslserver = tagion.testbench.sslserver;
    import bdd_mode1 = tagion.testbench.bdd_mode1;
    import bdd_services = tagion.testbench.bdd_services;
    import bdd_wallets = tagion.testbench.bdd_wallets;
    import ssl_echo_server = tagion.testbench.ssl_echo_server;

    alias alltools = AliasSeq!(
            sslclient,
            sslserver,
            bdd_mode1,
            bdd_services,
            bdd_wallets,
            ssl_echo_server,
    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
