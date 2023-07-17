module tagion.testbench.hashgraph_swap;

import tagion.behaviour.Behaviour;

import tagion.behaviour.Behaviour;
import tagion.testbench.functional;
import tagion.hibon.HiBONRecord : fwrite;
import tagion.tools.Basic;
import tagion.testbench.hashgraph;
import tagion.testbench.tools.Environment;
import std.stdio;
import std.path : buildPath;
import std.file : mkdirRecurse;

import tagion.testbench.hashgraph.hashgraph_test_network;


mixin Main!(_main);

int _main(string[] args) {

    const module_path = env.bdd_log.buildPath(__MODULE__);
    mkdirRecurse(module_path);
    writeln(args);
    auto node_names = args[1..$];

    TestNetwork network = new TestNetwork(node_names);



    
    auto hashgraph_swap_feature = automation!(swap_node);
    hashgraph_swap_feature.OfflineNodeSwap(node_names, network, module_path);
    hashgraph_swap_feature.run;
    return 0;
}