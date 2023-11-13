module tagion.testbench.replicator_service;

import std.file;
import std.path : buildPath;
import tagion.behaviour.Behaviour;
import tagion.services.replicator : ReplicatorOptions;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);
    immutable opts = ReplicatorOptions(module_path);
    auto recorder_service_feature = automation!(recorder_service);
    recorder_service_feature.StoreOfTheRecorderChain(opts);
    recorder_service_feature.run();
    return 0;

}
