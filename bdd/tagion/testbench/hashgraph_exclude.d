module tagion.testbench.hashgraph_exclude;

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
import tagion.crypto.Types;

import tagion.testbench.hashgraph.hashgraph_test_network;


mixin Main!(_main);

int _main(string[] args) {

    const module_path = env.bdd_log.buildPath(__MODULE__);
    mkdirRecurse(module_path);
    writeln(args);
    auto node_names = args[1..$];

    TestNetwork network = new TestNetwork(node_names);

    auto first_exclude = Pubkey(network.channels[$-1]);
    alias Hist = TestRefinement.ExcludedNodesHistory;
    TestRefinement.excluded_nodes_history = [
        Hist(first_exclude, true, 23),
    ];


    
    auto hashgraph_exclude_feature = automation!(exclude_node);
    hashgraph_exclude_feature.StaticExclusionOfANode(node_names, network, module_path);
    hashgraph_exclude_feature.run;
    return 0;
}