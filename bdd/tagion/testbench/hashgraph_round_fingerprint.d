module tagion.testbench.hashgraph_round_fingerprint;

import tagion.behaviour.Behaviour;
import tagion.testbench.functional;
import tagion.hibon.HiBONRecord : fwrite;
import tagion.tools.Basic;
import tagion.testbench.hashgraph;
import tagion.testbench.tools.Environment;
import std.stdio;
import std.path : buildPath;
import std.file : mkdirRecurse;

mixin Main!(_main);

int _main(string[] args) {
    const module_path = env.bdd_log.buildPath(__MODULE__);
    mkdirRecurse(module_path);
    writeln(args);
    auto hashgraph_round_fingerprint_feature = automation!(round_fingerprint);
    // hashgraph_round_fingerprint_feature.SameRoundFingerprintAcrossDifferentNodes(args[1..$], module_path);

    auto hashgraph_sync_network_context = hashgraph_round_fingerprint_feature.run();
    return 0;
}
