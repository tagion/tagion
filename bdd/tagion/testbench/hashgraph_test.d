module tagion.testbench.hashgraph_test;

import tagion.behaviour.Behaviour;
import tagion.testbench.functional;
import tagion.hibon.HiBONRecord : fwrite;
import tagion.tools.Basic;
import tagion.testbench.hashgraph;
import tagion.testbench.tools.Environment;
import std.stdio;

mixin Main!(_main);


int _main(string[] args) {
    writefln("HASHGRAPH NAMES %s", args);    
    auto hashgraph_sync_network_feature = automation!(synchron_network);
    auto hashgraph_sync_network_context = hashgraph_sync_network_feature.run();
    return 0;

}
