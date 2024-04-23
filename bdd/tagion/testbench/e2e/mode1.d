/// This program checks if we can start the network in mode1
module tagion.testbench.e2e.mode1;

import core.thread;
import core.time;

import std.stdio;
import std.format;
import std.file;
import std.getopt;
import std.path;
import std.process;
import std.range;
import std.algorithm;

import tagion.tools.Basic;
import tagion.tools.wallet.WalletOptions;
import tagion.tools.wallet.WalletInterface;
import tagion.services.options;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.hibon.Document;
import tagion.communication.HiRPC;
import tagion.services.subscription : SubscriptionPayload;
import tagion.testbench.tools.Environment : bddenv = env;
import tagion.wave.mode0 : dummy_nodenets_for_testing;
import tagion.dart.Recorder;
import tagion.dart.DART : DART;
import tagion.dart.DARTFile : DARTFile;
import tagion.crypto.SecureNet;
import tagion.hashgraph.Refinement;
import tagion.tools.subscriber : Subscription;

void kill_waves(Pid[] pids, Duration grace_time) {
    const begin_time = MonoTime.currTime;
    enum SIGINT = 2;
    enum SIGKILL = 9;

    Pid[size_t] alive_pids;
    foreach(i, pid; pids) {
        alive_pids[i] = pid;
        kill(pid, SIGINT);
        Thread.sleep(200.msecs);
        kill(pid, SIGINT);
        writefln("SIGINT: %s", pid.processID);
    }

    while(!alive_pids.empty || MonoTime.currTime - begin_time <= grace_time) {
        Thread.sleep(200.msecs);

        foreach(i, pid; alive_pids) {
            auto proc_status = tryWait(pid);
            writefln("%s: %s", pid.processID, proc_status);

            if(proc_status.terminated) {
                writeln("remove ", i); 
                alive_pids.remove(i);
            }
        }
    }

    foreach(pid; alive_pids) {
        kill(pid, SIGKILL);
        writefln("SIGKILL: %s", pid.processID);
        wait(pid);
    }
}

// Return: A range of options prefixed with the node number
const(Options)[] getMode1Options(uint number_of_nodes) {
    Options local_options;
    local_options.setDefault;
    local_options.wave.network_mode = NetworkMode.LOCAL;
    local_options.epoch_creator.timeout = 300; //msecs
    local_options.subscription.tags = StdRefinement.epoch_created.name;

    enum base_port = 10_700;

    Options[] all_opts;
    foreach (node_n; 0 .. number_of_nodes) {
        auto opt = Options(local_options);

        opt.task_names.setPrefix(format(opt.wave.prefix_format, node_n));
        opt.node_interface.node_address = format("tcp://[::1]:%s", base_port+node_n);

        all_opts ~= opt;
    }

    return all_opts;
}


import tagion.tools.boot.genesis;
// NodeSettings used to create the genesis epoch
const(NodeSettings[]) mk_node_settings(ref const(Options)[] node_opts) {
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

/* 
 * Creates the nodes config files and wallets 
 *
 * Params:
 *   node_opts = A list of node configuration
 * Returns: A list of directories to the node data
 */
string[] create_nodes_data(string genesis_dart_path, ref const(Options)[] node_opts, out string[] pins) {
    string[] node_paths;

    foreach(i, opt; node_opts) {
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
        wallet_interface.save(recover_flag: false);
        chdir("..");
    }
    return node_paths;
}

Pid[] spawn_nodes(string dbin, string[] pins, const(string[]) node_data_paths) {
    Pid[] pids;
    foreach(pin, node_path; zip(pins, node_data_paths)) {
        const cmd = [buildPath(dbin, "testbench"), "test_wave"];
        writefln("run: %s", cmd);

        const pin_path = buildPath(node_path, "pin.txt");

        import file = std.file;
        file.write(pin_path, pin);
        auto pin_file = File(pin_path, "r");

        Pid pid = spawnProcess(cmd, workDir: node_path, stdin: pin_file);
        writefln("Started %s", pid.processID);
        pids ~= pid;
    }
    return pids;
}

mixin Main!(_main);

int _main(string[] args) {
    immutable program = args[0];
    uint number_of_nodes = 5;
    uint timeout_secs = 100;

    auto main_args = getopt(args,
        "n|nodes", format("Amount of nodes to spawn (%s)", number_of_nodes), &number_of_nodes,
        "t|timeout", format("How long to run the test for in seconds (%s)", timeout_secs), &timeout_secs,
        "v|verbose", "Vebose switch", &__verbose_switch,
    );

    if(main_args.helpWanted) {
        defaultGetoptPrinter(
                "Help information for mode1 test program\n" ~
                format("Usage: %s", program),
                main_args.options
        );
        return 0;
    }

    auto module_path = bddenv.bdd_log.buildPath(__MODULE__);

    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);
    chdir(module_path);

    auto node_opts = getMode1Options(number_of_nodes);

    auto feature = automation!(mixin(__MODULE__));
    feature.Mode1NetworkStart(node_opts, timeout_secs.seconds);
    feature.run;

    return 0;
}

// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "basic mode1 test",
            []);

alias FeatureContext = Tuple!(
        Mode1NetworkStart, "Mode1NetworkStart",
        FeatureGroup*, "result"
);

@trusted @Scenario("mode1 network start",
        [])
class Mode1NetworkStart {
    const(Options)[] node_opts;
    Duration timeout;

    enum expected_epoch = 5;

    
    this(const(Options)[] node_opts, Duration timeout) {
        this.node_opts = node_opts;
        this.timeout = timeout;
    }

    Pid[] pids;

    @Given("i have a network started in mode1")
    Document mode1() {

        // create recorder
        SecureNet net = new StdSecureNet();
        net.generateKeyPair("very_secret");

        const genesis_node_settings = mk_node_settings(node_opts);
        const genesis_doc = createGenesis(genesis_node_settings, Document(), TagionGlobals.init);

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder;
        recorder.insert(genesis_doc, Archive.Type.ADD);

        const genesis_dart_path = "genesis_dart.drt";

        TagionHead tagion_head;
        tagion_head.name = TagionDomain;
        tagion_head.current_epoch = 0;
        recorder.add(tagion_head);

        DARTFile.create(genesis_dart_path, net);
        auto db = new DART(net, genesis_dart_path);
        db.modify(recorder);

        string[] pins;
        const node_data_paths = create_nodes_data(genesis_dart_path, node_opts, pins);

        const dbin = bddenv.dbin;
        pids = spawn_nodes(dbin, pins, node_data_paths);
        return result_ok;
    }

    @When("all nodes have produced 5 epochs")
    Document epochs() {
        Subscription[] subs;
        long[] epochs;

        foreach(opt; node_opts) {
            auto sub =  Subscription(opt.subscription.address, [StdRefinement.epoch_created.name]);
            sub.dial;
            subs ~= sub;
            epochs ~= -1;
        }

        Thread.sleep(5.seconds);

        const begin_time = MonoTime.currTime;
        HiRPC hirpc = HiRPC(null);

        while(!epochs.all!(i => i >= expected_epoch) && MonoTime.currTime - begin_time <= timeout) {
            foreach(i, sub; subs) {
                auto doc = sub.receive();
                if(doc.error) {
                    writeln(doc.e.message);
                    continue;
                }

                writeln(doc.get.toPretty);

                const rec_hirpc = hirpc.receive(doc.get);
                const payload = SubscriptionPayload(rec_hirpc.method.params);
                const finished_epoch = FinishedEpoch(payload.data);
                epochs[i] = finished_epoch.epoch;
            }
        }

        check(epochs.all!(i => i >= expected_epoch), format("%s", epochs));

        writefln("Nodes ended at epochs %s", epochs);

        return result_ok;
    }

    @Then("i stop the network")
    Document network() {
        kill_waves(pids, grace_time: 3.seconds);
        return result_ok;
    }

}
