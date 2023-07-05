module tagion.testbench.hashgraph_contributors;

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
import tagion.crypto.Types;


mixin Main!(_main);

int _main(string[] args) {
    const module_path = env.bdd_log.buildPath(__MODULE__);
    mkdirRecurse(module_path);
    writeln(args);
    auto node_names = args[1..$];

    TestNetwork network = new TestNetwork(node_names);
    auto first_exclude = Pubkey(network.channels[$-1]);
    auto second_exclude = Pubkey(network.channels[$-2]);
    auto third_exclude = Pubkey(network.channels[$-3]);

    alias Hist = TestRefinement.ExcludedNodesHistory;
    TestRefinement.excluded_nodes_history = [
        Hist(first_exclude, true, 23),
        Hist(second_exclude, true, 23),
        Hist(first_exclude, false, 29),
        Hist(second_exclude, false, 30),
    ];
    auto hashgraph_contributors_feature = automation!(graph_contributors);
    hashgraph_contributors_feature.ANonvotingNode(node_names, network, module_path);
    hashgraph_contributors_feature.run();



    const second_module_path = env.bdd_log.buildPath(__MODULE__ ~ "_non_consensus");
    mkdirRecurse(second_module_path);
    auto hashgraph_non_consensus_feature = automation!(graph_contributors);
    hashgraph_non_consensus_feature.alternative = "non_consensus";

    TestRefinement.excluded_nodes_history = [
        Hist(first_exclude, true, 23),
        Hist(second_exclude, true, 24),
        Hist(third_exclude, true, 29),
    ];
    TestRefinement.epoch_events = null;
    network = new TestNetwork(node_names);

    
    hashgraph_non_consensus_feature.ANonvotingNode(node_names, network, second_module_path);
    hashgraph_non_consensus_feature.run();
    return 0;
}