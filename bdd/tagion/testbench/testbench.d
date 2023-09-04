module tagion.testbench.testbench;

import std.meta;

import tagion.tools.OneMain;

int main(string[] args) {
    import ssl_server = tagion.testbench.ssl_server;
    import hirpc_verifier = tagion.testbench.hirpc_verifier;
    import inputvalidator = tagion.testbench.inputvalidator;
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
    import actor_tests = tagion.testbench.actor_tests;
    import dart_insert_remove_stress = tagion.testbench.dart_insert_remove_stress;
    import dart_sync_stress = tagion.testbench.dart_sync_stress;
    import dart_service = tagion.testbench.dart_service;
    import hashgraph_test = tagion.testbench.hashgraph_test;
    import hashgraph_swap = tagion.testbench.hashgraph_swap;
    import tvm_betterc = tagion.testbench.tvm_betterc;
    import epoch_creator = tagion.testbench.epoch_creator;
    import tvm_service = tagion.testbench.tvm_service;
    import transcript_service = tagion.testbench.transcript_service;

    alias alltools = AliasSeq!(
            ssl_server,
            hirpc_verifier,
            inputvalidator,
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
            actor_tests,
            dart_insert_remove_stress,
            dart_sync_stress,
            dart_service,
            hashgraph_test,
            hashgraph_swap,
            tvm_betterc,
            epoch_creator,
            tvm_service,
            transcript_service,
    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
