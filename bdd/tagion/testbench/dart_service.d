module tagion.testbench.dart_service;

import tagion.tools.Basic;
import tagion.behaviour.Behaviour;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import std.file;
import tagion.services.DART : DARTOptions;
import tagion.services.replicator : ReplicatorOptions;

import std.path : setExtension, buildPath;
import tagion.basic.Types : FileExtension;

mixin Main!(_main);

int _main(string[] args) {

    auto module_path = env.bdd_log.buildPath(__MODULE__);
    mkdirRecurse(module_path);
    auto opts = DARTOptions(buildPath(module_path, "dart".setExtension(FileExtension.dart)));
    auto replicator_path = buildPath(module_path, "replicator");
    mkdirRecurse(replicator_path);
    auto replicator_opts = ReplicatorOptions(replicator_path);

    auto dart_service_feature = automation!(DARTService);

    dart_service_feature.WriteAndReadFromDartDb(opts, replicator_opts);
    dart_service_feature.run();

    return 0;
}
