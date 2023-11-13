module tagion.testbench.collector;

import std.traits : moduleName;
import tagion.behaviour.Behaviour;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {
    auto collector_feature = automation!collector;
    collector_feature.ItWork();
    collector_feature.run;

    return 0;
}
