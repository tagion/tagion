module tagion.testbench.hashgraph_swap;

import std.conv;
import std.file : mkdirRecurse;
import std.format;
import std.path : buildPath;
import std.stdio;
import tagion.behaviour.Behaviour;
import tagion.behaviour.Behaviour;
import tagion.testbench.hashgraph;
import tagion.testbench.hashgraph.hashgraph_test_network;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {

    const module_path = env.bdd_log.buildPath(__MODULE__);
    mkdirRecurse(module_path);
    writeln(args);
    stdout.flush;
    const node_amount = args[1].to!uint;
    const calls = args[2].to!uint;
    string[] node_names;
    foreach (i; 0 .. node_amount) {
        node_names ~= format("Node%d", i);
    }

    auto hashgraph_swap_feature = automation!(swap);
    hashgraph_swap_feature.NodeSwap(node_names, calls, module_path);
    hashgraph_swap_feature.run;
    return 0;
}
