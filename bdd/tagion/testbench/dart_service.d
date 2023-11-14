module tagion.testbench.dart_service;

import std.file;
import std.path : buildPath, setExtension;
import tagion.basic.Types : FileExtension;
import tagion.behaviour.Behaviour;
import tagion.services.DART : DARTOptions;
import tagion.services.replicator : ReplicatorOptions;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {

    auto module_path = env.bdd_log.buildPath(__MODULE__);
    mkdirRecurse(module_path);
    auto opts = DARTOptions(module_path, "dart".setExtension(FileExtension.dart));
    auto replicator_path = buildPath(module_path, "replicator");
    mkdirRecurse(replicator_path);
    auto replicator_opts = ReplicatorOptions(replicator_path);

    auto dart_service_feature = automation!(DARTService);

    dart_service_feature.WriteAndReadFromDartDb(opts, replicator_opts);
    dart_service_feature.run();

    return 0;
}
