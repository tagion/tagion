module tagion.testbench.testbench;

import std.meta;
import tagion.tools.OneMain;

int main(string[] args) {
    import actor_tests = tagion.testbench.actor_tests;
    import collector = tagion.testbench.collector;
    import dart_deep_rim_test = tagion.testbench.dart_deep_rim_test;
    import dart_insert_remove_stress = tagion.testbench.dart_insert_remove_stress;
    import dart_partial_sync = tagion.testbench.dart_partial_sync;
    import dart_pseudo_random_archives = tagion.testbench.dart_pseudo_random_archives;
    import dart_service = tagion.testbench.dart_service;
    import dart_stress = tagion.testbench.dart_stress;
    import dart_sync = tagion.testbench.dart_sync;
    import dart_sync_stress = tagion.testbench.dart_sync_stress;
    import dart_test = tagion.testbench.dart_test;
    import double_spend = tagion.testbench.double_spend;
    import epoch_creator = tagion.testbench.epoch_creator;
    import hashgraph_swap = tagion.testbench.hashgraph_swap;
    import hashgraph_test = tagion.testbench.hashgraph_test;
    import run_fiber_epoch = tagion.testbench.hashgraph.run_fiber_epoch;
    import hirpc_verifier = tagion.testbench.hirpc_verifier;
    import inputvalidator = tagion.testbench.inputvalidator;
    import subscription_test = tagion.testbench.services.subscription_test;
    import malformed_contract = tagion.testbench.malformed_contract;
    import send_contract = tagion.testbench.send_contract;
    import spam_double_spend = tagion.testbench.spam_double_spend;
    import transcript_service = tagion.testbench.transcript_service;
    import tvm_betterc = tagion.testbench.tvm_betterc;
    import operational = tagion.testbench.e2e.operational;
    import genesis_test = tagion.testbench.genesis_test;
    import trt_service = tagion.testbench.services.trt_service;
    import big_contract = tagion.testbench.services.big_contract;
    import transaction = tagion.testbench.e2e.transaction;
    import run_epochs = tagion.testbench.e2e.run_epochs;
    import mode1 = tagion.testbench.e2e.mode1;
    import test_wave = tagion.testbench.e2e.test_wave;
    import trt_contract = tagion.testbench.trt_contract;
    import dartutil_test = tagion.testbench.testtools.dartutil_test;
    import hirep_test = tagion.testbench.testtools.hirep_test;
    import hibonutil_test = tagion.testbench.testtools.hibonutil_test;
    import wallet_test = tagion.testbench.testtools.wallet_test;
    import epoch_shutdown = tagion.testbench.services.epoch_shutdown;

    alias alltools = AliasSeq!(
        collector,
        hirpc_verifier,
        inputvalidator,
        subscription_test,
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
        transcript_service,
        send_contract,
        double_spend,
        spam_double_spend,
        malformed_contract,
        operational,
        genesis_test,
        trt_service,
        big_contract,
        transaction,
        run_epochs,
        mode1,
        test_wave,
        run_fiber_epoch,
        trt_contract,
        dartutil_test,
        hirep_test,
        hibonutil_test,
        wallet_test,
        epoch_shutdown,
    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
