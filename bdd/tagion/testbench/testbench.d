module tagion.testbench.testbench;

import std.meta;

import tagion.tools.OneMain;

int main(string[] args) {
    import ssl_server = tagion.testbench.ssl_server;
    import bdd_services = tagion.testbench.bdd_services;
    import ssl_echo_server = tagion.testbench.ssl_echo_server;
    import transaction = tagion.testbench.transaction;
    import receive_epoch = tagion.testbench.receive_epoch;
    import transaction_mode_zero = tagion.testbench.transaction_mode_zero;
    import dart_test = tagion.testbench.dart_test;
    import dart_deep_rim_test = tagion.testbench.dart_deep_rim_test;
    import dart_pseudo_random_archives = tagion.testbench.dart_pseudo_random_archives;
    import dart_sync = tagion.testbench.dart_sync;
    import dart_partial_sync = tagion.testbench.dart_partial_sync;
    import dart_stress = tagion.testbench.dart_stress;

    alias alltools = AliasSeq!(
            ssl_server,
            bdd_services,
            ssl_echo_server,
            transaction,
            receive_epoch,  
            transaction_mode_zero,
            dart_test,
            dart_deep_rim_test,
            dart_pseudo_random_archives,
            dart_sync,
            dart_partial_sync,
            dart_stress,
    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
