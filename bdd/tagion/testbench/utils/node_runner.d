module bdd.tagion.testbench.utils.node_runner;

// --- Core D modules ---
import core.thread;
import core.time;

import std.algorithm;
import std.exception;
import std.file;
import std.format;
import std.getopt;
import std.path;
import std.path : baseName, buildPath, stripExtension;
import std.process;
import std.range;
import std.stdio;
import std.typecons : Tuple;

// --- Tagion base modules ---
import tagion.actor;
import tagion.behaviour;
import tagion.hashgraph.Refinement;
import tagion.hibon.Document;
import tagion.logger.subscription;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.services.nodeinterface;
import tagion.services.options;
import tagion.testbench.actor.util;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions;
import tagion.tools.boot.genesis;
import tagion.utils.pretend_safe_concurrency : receive, receiveOnly, receiveTimeout, register, thisTid;
import tagion.wave.mode0 : dummy_nodenets_for_testing;
import tagion.logger.Logger;
import tagion.gossip.AddressBook;

class NodeRunner {

    uint number_of_nodes;
    uint timeout_msecs;
    const(Options)[] node_opts;
    Pid[] pids;
    shared(AddressBook) addressbook;

    this(uint number_of_nodes, uint timeout_msecs) {
        this.number_of_nodes = number_of_nodes;
        this.timeout_msecs = timeout_msecs;
        this.addressbook = new shared(AddressBook);
    }

    string[] collectDartAdresses() {
        string[] sock_addrs;
        foreach (opt; node_opts) {
            sock_addrs ~= opt.rpcserver.sock_addr;
        }
        return sock_addrs;
    }

    
    // shared(AddressBook) addressbook = new shared(AddressBook);
    // nodes ~= Node(shared_net, task_names, epoch_creator_options);
    // addressbook.set(new NetworkNodeRecord(net.pubkey, task_names.node_interface));

    void setupMode1Options(string prefix_name = "Mode_1_") {
        Options local_options;
        local_options.setDefault;
        local_options.trt.enable = false;
        local_options.wave.number_of_nodes = number_of_nodes;
        local_options.wave.network_mode = NetworkMode.LOCAL;
        local_options.epoch_creator.timeout = timeout_msecs;
        local_options.wave.prefix_format = prefix_name ~ "%s_";
        local_options.subscription.tags =
            [
                StdRefinement.epoch_created.name,
                NodeInterfaceService.node_action_event.name,
            ].join(",");

        enum base_port = 10_700;

        foreach (node_n; 0 .. number_of_nodes) {
            auto opt = Options(local_options);

            const prefix_f = format(opt.wave.prefix_format, node_n);
            opt.task_names.setPrefix(prefix_f);
            opt.rpcserver.setPrefix(prefix_f);
            opt.subscription.setPrefix(prefix_f);
            opt.node_interface.node_address = format("tcp://[::2]:%s", base_port + node_n);

            node_opts ~= opt;
        }
    }

    Document[] getGenesisDoc() {
        import tagion.script.namerecords : NetworkNodeRecord;

        NodeSettings[] node_settings;
        auto nodenets = dummy_nodenets_for_testing(node_opts);
        foreach (opt, node_net; zip(node_opts, nodenets)) {
            node_settings ~= NodeSettings(
                opt.task_names.epoch_creator,
                node_net.pubkey,
                opt.node_interface.node_address,
            );
            // addressbook.set(new NetworkNodeRecord(node_net.pubkey, opt.task_names.node_interface));
            addressbook.set(new NetworkNodeRecord(node_net.pubkey, opt.rpcserver.sock_addr));
        }

        return createGenesis(node_settings, Document(), TagionGlobals.init);
    }


    string[] createNodesData(string genesis_dart_path, out string[] pins) {
        string[] node_paths;

        foreach (i, opt; node_opts) {
            string node_path = format("node%s", i);
            node_paths ~= node_path;
            mkdir(node_path);

            const node_dart_path = buildPath(node_path, opt.dart.dart_path);
            copy(genesis_dart_path, node_dart_path);
            writeln("Copied ", node_dart_path);

            opt.save(buildPath(node_path, "tagionwave.json"));

            WalletOptions wallet_opts;
            wallet_opts.setDefault();
            const wallet_config = buildPath(node_path, "wallet.json");
            wallet_opts.save(wallet_config);

            auto wallet_interface = WalletInterface(wallet_opts);

            string pin = format("%04s", i);
            pins ~= pin;
            // This is the passphrase used by "dummy_nodenets_for_testing()"
            wallet_interface.generateSeedFromPassphrase(opt.task_names.supervisor, pin);
            chdir(node_path);
            wallet_interface.save(recover_flag : false);
            chdir("..");
        }
        return node_paths;
    }

    void spawnNodes(string dbin, string[] pins, const(string[]) node_data_paths) {
        foreach (pin, node_path; zip(pins, node_data_paths)) {
            const cmd = [buildPath(dbin, "testbench"), "test_wave"];
            log("run: %s", cmd);

            const pin_path = buildPath(node_path, "pin.txt");

            import file = std.file;

            file.write(pin_path, pin);
            auto pin_file = File(pin_path, "r");

            Pid pid = spawnProcess(cmd, workDir:
                node_path, stdin:
                pin_file);
            Thread.sleep(300.msecs);
            log("Started %s", pid.processID);
            pids ~= pid;
        }
    }

    void killWaves(Duration grace_time) {
        const begin_time = MonoTime.currTime;
        enum SIGINT = 2;
        enum SIGKILL = 9;

        Pid[size_t] alive_pids;
        foreach (i, pid; pids) {
            try {
                alive_pids[i] = pid;
                kill(pid, SIGINT);
                Thread.sleep(200.msecs);
                kill(pid, SIGINT);
                log("SIGINT: %s", pid.processID);
            }
            catch (Exception _) {
            }
        }

        while (!alive_pids.empty || MonoTime.currTime - begin_time <= grace_time) {
            Thread.sleep(200.msecs);

            foreach (i, pid; alive_pids) {
                try {
                    auto proc_status = tryWait(pid);
                    log("%s: %s", pid.processID, proc_status);

                    if (proc_status.terminated) {
                        writeln("remove ", i);
                        alive_pids.remove(i);
                    }
                }
                catch (Exception _) {
                }
            }
        }

        foreach (pid; alive_pids) {
            try {
                kill(pid, SIGKILL);
                log("SIGKILL: %s", pid.processID);
                wait(pid);
            }
            catch (Exception _) {
            }
        }
    }
}
