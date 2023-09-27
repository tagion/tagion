module tagion.testbench.send_contract;
import tagion.tools.Basic;
import tagion.behaviour.Behaviour;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import std.file;

import std.path : setExtension, buildPath;
import tagion.basic.Types : FileExtension;


import tagion.services.options;
import core.time;
import core.thread;
import std.stdio;


import std.process;

mixin Main!(_main);

int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);
    auto config_file = buildPath(module_path, "tagionwave.json");

    scope Options local_options = Options.defaultOptions;
    local_options.dart.folder_path = buildPath(module_path, "dart");
    local_options.replicator.folder_path = buildPath(module_path, "replicator");
    local_options.save(config_file);
    
    auto send_contract_feature = automation!(sendcontract);



    string[] neuewelle_command = [
        tools.neuewelle,
        config_file,
    ];
    
    auto tid = spawnProcess(neuewelle_command, stdin, stdout, stderr);
    Thread.sleep(10.seconds);
    

    send_contract_feature.run();

    return 0;

}

