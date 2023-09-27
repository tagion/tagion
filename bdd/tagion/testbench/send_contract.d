module tagion.testbench.send_contract;
import tagion.tools.Basic;
import tagion.behaviour.Behaviour;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import std.file;

import std.path : setExtension, buildPath;
import tagion.basic.Types : FileExtension;


import tagion.actor;
import tagion.services.locator;
import tagion.logger.Logger;
import tagion.services.supervisor;
import tagion.services.options;
import tagion.GlobalSignals;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.gossip.AddressBook : addressbook, NodeAddress;
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

    scope Options local_options = Options.defaultOptions;
    immutable wave_options = Options(local_options).wave;

    auto send_contract_feature = automation!(sendcontract);

    string[] neuewelle_command = [
        tools.neuewelle,
    ];
    
    auto tid = spawnProcess(neuewelle_command, stdin, stdout, stderr);
    Thread.sleep(10.seconds);
    

    send_contract_feature.run();

    return 0;

}

