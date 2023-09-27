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



mixin Main!(_main);

int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    mkdirRecurse(module_path);



    
    // import tagion.tools.neuewelle : startLogger;
    // auto logger_service_tid = startLogger;
    // scope (exit) {
    //     import tagion.basic.Types : Control;

    //     logger_service_tid.control(Control.STOP);
    //     receiveOnly!Control;
    // }

    scope Options local_options = Options.defaultOptions;
    immutable wave_options = Options(local_options).wave;
    locator_options = new immutable(LocatorOptions)(5, 5);
    ActorHandle!Supervisor[] supervisor_handles;

    struct Node {
        immutable(Options) opts;
        immutable(SecureNet) net;
    }

    Node[] nodes;

    foreach (i; 0 .. wave_options.number_of_nodes) {
        immutable prefix = format("Node_%s_", i);
        auto opts = Options(local_options);
        

        
        opts.setPrefix(prefix);
        SecureNet net = new StdSecureNet();
        net.generateKeyPair(opts.task_names.supervisor);
        opts.epoch_creator.timeout = 1000;


        nodes ~= Node(opts, cast(immutable) net);

        addressbook[net.pubkey] = NodeAddress(opts.task_names.epoch_creator);
    }

    /// spawn the nodes
    foreach (n; nodes) {
        supervisor_handles ~= spawn!Supervisor(n.opts.task_names.supervisor, n.opts, n.net);
    }
    if (waitforChildren(Ctrl.ALIVE, 10.seconds)) {
        log("alive");
        stopsignal.wait;
    }
    else {
        log("Program did not start");
        return 1;
    }

    log("Sending stop signal to supervisor");
    foreach (supervisor; supervisor_handles) {
        supervisor.send(Sig.STOP);
    }
    // supervisor_handle.send(Sig.STOP);
    if (!waitforChildren(Ctrl.END)) {
        log("Program did not stop properly");
        return 1;
    }
    log("Exiting");

    return 0;

}

