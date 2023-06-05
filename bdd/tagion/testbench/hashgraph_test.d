module tagion.testbench.hashgraph_test;

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

    auto hashgraph_sync_network_feature = automation!(synchron_network);
    hashgraph_sync_network_feature.StartNetworkWithNAmountOfNodes(args, module_path);
    auto hashgraph_sync_network_context = hashgraph_sync_network_feature.run();
    return 0;
}
