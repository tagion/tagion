module tagion.testbench.utils.create_network;

import core.time;

import std.algorithm;
import std.array;
import std.range;
import std.format;
import std.range;
import std.stdio;
import std.path;
import std.file;
import std.exception;

import tagion.actor;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.Recorder;
import tagion.script.TagionCurrency;
import tagion.script.common : TagionBill;
import tagion.utils.pretend_safe_concurrency;
import tagion.testbench.services.sendcontract;
import tagion.trt.TRT;
import tagion.wallet.SecureWallet;
import tagion.tools.boot.genesis;
import tagion.services.options;
import tagion.logger;
import tagion.logger.LogRecords;
import tagion.script.common;
import tagion.hibon.Document;
import tagion.hibon.BigNumber;
import tagion.hibon.HiBONRecord;
import tagion.wave.mode0;
import tagion.testbench.tools.Environment: bddenv = env;
import tagion.hashgraph.Refinement;
import neuewelle = tagion.tools.neuewelle;

@trusted
void wrap_neuewelle(immutable(string)[] args) {
    neuewelle._main(cast(string[])args);
}

@safe
class TestNetwork {
    string module_path;
    string module_name;
    string config_file;
    immutable(string)[] neuewelle_args;
    Options local_options;
    const(Options)[] node_opts;

    this(string module_name = __MODULE__) {
        this.module_name = module_name;
        this.module_path = buildPath(bddenv.bdd_log, module_name);
        this.config_file = buildPath(module_path, "tagionwave.json");
        this.neuewelle_args = [module_name, this.config_file];

        this.local_options = Options.defaultOptions;
        local_options.dart.folder_path = buildPath(module_path);
        local_options.subscription.enable = false;
        local_options.trt.folder_path = buildPath(module_path);
        local_options.replicator.folder_path = buildPath(module_path, "recorders");
        local_options.epoch_creator.timeout = 100;

        this.node_opts = getMode0Options(local_options);
    }

    void create_files() {
        if (module_path.exists) {
            rmdirRecurse(module_path);
        }
        mkdirRecurse(module_path);
        local_options.save(config_file);

        StdSecureWallet[] wallets;
        // create the wallets
        foreach (i; 0 .. 5) {
            StdSecureWallet secure_wallet;
            secure_wallet = StdSecureWallet(
                iota(0, 5)
                    .map!(n => format("%dquestion%d", i, n)).array,
                    iota(0, 5)
                    .map!(n => format("%danswer%d", i, n)).array,
                    4,
                    format("%04d", i),
            );
            wallets ~= secure_wallet;
        }

        // bills for the dart on startup
        TagionBill[] bills;
        foreach (ref wallet; wallets) {
            bills ~= wallet.requestBill(1000.TGN);
            bills ~= wallet.requestBill(2000.TGN);
        }

        // create the recorder
        SecureNet net = new StdSecureNet();
        net.generateKeyPair("very_secret");

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder;
        recorder.insert(bills, Archive.Type.ADD);

        NodeSettings[] node_settings;
        auto nodenets = dummy_nodenets_for_testing(node_opts);
        foreach (opt, node_net; zip(node_opts, nodenets)) {
            node_settings ~= NodeSettings(
                opt.task_names.epoch_creator, // Name
                node_net.pubkey,
                opt.task_names.epoch_creator, // Address
            );
        }

        const genesis = createGenesis(
            node_settings,
            Document(), 
            TagionGlobals(BigNumber(bills.map!(a => a.value.units).sum), BigNumber(0), bills.length, 0)
        );

        recorder.insert(genesis, Archive.Type.ADD);

        string dart_interface_sock_addr;
        string inputvalidator_sock_addr;
        // create the databases
        foreach (i; 0 .. local_options.wave.number_of_nodes) {
            immutable prefix = format(local_options.wave.prefix_format, i);

            if (i == 0) {
                auto _opts = Options(local_options);
                _opts.setPrefix(prefix);
                dart_interface_sock_addr = _opts.dart_interface.sock_addr;
                inputvalidator_sock_addr = _opts.inputvalidator.sock_addr;
            }
            const path = buildPath(local_options.dart.folder_path, prefix ~ local_options
                    .dart.dart_filename);
            writeln("DART path: ", path);
            DARTFile.create(path, net);
            auto db = new DART(net, path);
            db.modify(recorder);
            db.close;
        }

        // Inisialize genesis TRT
        if (local_options.trt.enable) {
            auto trt_recorder = factory.recorder;
            genesisTRT(bills, trt_recorder, net);

            foreach (i; 0 .. local_options.wave.number_of_nodes) {
                immutable prefix = format(local_options.wave.prefix_format, i);

                const trt_path = buildPath(local_options.trt.folder_path, prefix ~ local_options
                        .trt.trt_filename);
                writeln("TRT path: ", trt_path);
                DARTFile.create(trt_path, net);
                auto trt_db = new DART(net, trt_path);
                trt_db.modify(trt_recorder);
            }
        }
    }

    Tid start_network() {
        Tid tid = spawn(&wrap_neuewelle, neuewelle_args);
        return tid;
    }

    long[string] epochs;
    bool wait_for_epochs(long expected_epoch, Duration timeout) {
        const begin_time = MonoTime.currTime;

        bool all_epochs_reached() {
            return epochs.byValue.all!(i => i >= expected_epoch) && epochs.length >= local_options.wave.number_of_nodes;
        }

        while(!all_epochs_reached() && MonoTime.currTime - begin_time <= timeout) {
            receiveTimeout(1.seconds, (LogInfo loginfo, const(Document) doc) {
                writefln("REFINEMENT SUB %s", doc.toPretty);
                if(!doc.isRecord!FinishedEpoch) {
                    return;
                }
                const finished_epoch = FinishedEpoch(doc);
                epochs[loginfo.task_name] = finished_epoch.epoch;
            });
        }
        return all_epochs_reached();
    }

}
