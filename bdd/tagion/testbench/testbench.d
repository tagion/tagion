module tagion.testbench.testbench;

import std.meta;

import tagion.tools.OneMain;

int main(string[] args) {
    import ssl_server = tagion.testbench.ssl_server;
    import bdd_services = tagion.testbench.bdd_services;
    import ssl_echo_server = tagion.testbench.ssl_echo_server;
    import transaction = tagion.testbench.transaction;
    alias alltools = AliasSeq!(
            ssl_server,
            bdd_services,
            ssl_echo_server,
            transaction,

    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
