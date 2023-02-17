module tagion.testbench.dart_test;


import tagion.behaviour.Behaviour;
import tagion.testbench.functional;
import tagion.hibon.HiBONType : fwrite;
import tagion.tools.Basic;
import std.traits : moduleName;

import tagion.testbench.dart;
import tagion.testbench.tools.BDDOptions;


mixin Main!(_main);


int _main(string[] args) {
    BDDOptions bdd_options;
    setDefaultBDDOptions(bdd_options);
    bdd_options.scenario_name = __MODULE__;

    auto dart_mapping_two_archives_feature = automation!(dart_mapping_two_archives)();
    dart_mapping_two_archives_feature.AddOneArchive(bdd_options);
    auto dart_mapping_two_archives_context = dart_mapping_two_archives_feature.run();

    return 0;
}



