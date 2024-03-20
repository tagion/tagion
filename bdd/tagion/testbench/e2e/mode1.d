/// This program checks if we can start the network in mode1
module tagion.testbench.e2e.mode1;

import core.thread;
import core.time;

import std.stdio;
import std.format;
import std.file : mkdirRecurse, rmdirRecurse, exists;
import std.path;
import std.process;
import std.range;
import std.algorithm;

import tagion.tools.Basic;
import tagion.services.options;
import tagion.script.common;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment : bddenv = env;
import neuewelle = tagion.tools.neuewelle;
import tagion.wave.mode0 : dummy_nodenets_for_testing;
import tagion.dart.Recorder;
import tagion.crypto.SecureNet;

void kill_waves(Pid[] pids, Duration grace_time) {
    const begin_time = MonoTime.currTime;

    foreach(pid; pids) {
        kill(pid);
        writefln("SIGINT: %s", pid.processID);
    }

    Pid[] alive_pids = pids;
    while(!alive_pids.empty || MonoTime.currTime - begin_time <= grace_time) {
        foreach(i, pid; alive_pids) {
            auto proc_status = tryWait(pid);
            if(proc_status.terminated) {
                alive_pids = alive_pids.remove(i);
            }
            writefln("%s: %s", pid.processID, proc_status);
        }
        Thread.sleep(100.msecs);
    }

    foreach(pid; alive_pids) {
        kill(pid, 9);
        writefln("SIGKILL: %s", pid.processID);
    }
}

// Return: A range of options prefixed with the node number
const(Options)[] getMode1Options(uint number_of_nodes) {
    Options local_options;
    local_options.setDefault;

    // The prefix is not needed necessary in mode1. But it's nice to be able to see the nodes in the log.
    const prefix_f = local_options.wave.prefix_format;

    enum base_port = 10_700;

    Options[] all_opts;
    foreach (node_n; 0 .. number_of_nodes) {
        auto opt = Options(local_options);
        opt.setPrefix(format(prefix_f, node_n));
        all_opts ~= opt;

        opt.node_interface.node_address = format("tcp://::1:%s", base_port+node_n);
    }

    return all_opts;
}


import tagion.tools.boot.genesis;
// NodeSettings used to create the genesis epoch
const(NodeSettings[]) mk_node_settings(const(Options)[] node_opts) {
    NodeSettings[] node_settings;
    auto nodenets = dummy_nodenets_for_testing(node_opts);
    foreach (opt, node_net; zip(node_opts, nodenets)) {
        node_settings ~= NodeSettings(
            opt.task_names.epoch_creator, // Name
            node_net.pubkey,
            opt.node_interface.node_address, // Address
        );
    }
    return node_settings;
}

mixin Main!(_main);

int _main(string[] _) {
    enum number_of_nodes = 5;

    auto module_path = bddenv.bdd_log.buildPath(__MODULE__);

    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);

    // create recorder
    SecureNet net = new StdSecureNet();
    net.generateKeyPair("very_secret");

    auto factory = RecordFactory(net);
    auto recorder = factory.recorder;

    auto node_opts = getMode1Options(number_of_nodes);
    const genesis_node_settings = mk_node_settings(node_opts);
    createGenesis(genesis_node_settings, Document(), TagionGlobals.init);


    const dbin = bddenv.dbin;
    auto pid = spawnProcess(buildPath(dbin, "neuewelle"));

    writefln("Started %s", pid.processID);



    Thread.sleep(3.seconds);

    kill_waves([pid], 3.seconds);
    return 0;
}
