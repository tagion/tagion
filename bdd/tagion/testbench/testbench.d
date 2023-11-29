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
    import hirpc_verifier = tagion.testbench.hirpc_verifier;
    import inputvalidator = tagion.testbench.inputvalidator;
    import malformed_contract = tagion.testbench.malformed_contract;
    import replicator_service = tagion.testbench.replicator_service;
    import send_contract = tagion.testbench.send_contract;
    import spam_double_spend = tagion.testbench.spam_double_spend;
    import transcript_service = tagion.testbench.transcript_service;
    import tvm_betterc = tagion.testbench.tvm_betterc;
    import operational = tagion.testbench.e2e.operational;
    import genesis_test = tagion.testbench.genesis_test;
    import trt_service = tagion.testbench.services.trt_service;
    import big_contract = tagion.testbench.services.big_contract;

    alias alltools = AliasSeq!(
            collector,
            hirpc_verifier,
            inputvalidator,
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
            replicator_service,
            send_contract,
            double_spend,
            spam_double_spend,
            malformed_contract,
            operational,
            genesis_test,
            trt_service,
            big_contract,
    );
    mixin doOneMain!(alltools);
    return do_main(args);
}
