module tagion.testbench.send_contract;
import core.thread;
import core.time;
import std.file;
import std.path : buildPath, setExtension;
import std.stdio;
import tagion.GlobalSignals;
import tagion.basic.Types : FileExtension;
import tagion.behaviour.Behaviour;
import tagion.logger.Logger;
import tagion.services.options;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import neuewelle = tagion.tools.neuewelle;
import tagion.utils.pretend_safe_concurrency;

mixin Main!(_main);

void wrap_neuewelle(immutable(string)[] args) {
    neuewelle._main(cast(string[]) args);
}

int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);
    string config_file = buildPath(module_path, "tagionwave.json");

    scope Options local_options = Options.defaultOptions;
    local_options.dart.folder_path = buildPath(module_path);
    local_options.trt.folder_path = buildPath(module_path);
    local_options.replicator.folder_path = buildPath(module_path, "recorders");
    local_options.epoch_creator.timeout = 500;
    local_options.save(config_file);

    import std.algorithm;
    import std.array;
    import std.format;
    import std.range;
    import std.stdio;
    import tagion.crypto.SecureInterfaceNet;
    import tagion.crypto.SecureNet : StdSecureNet;
    import tagion.dart.DART;
    import tagion.dart.DARTFile;
    import tagion.dart.Recorder;
    import tagion.script.TagionCurrency;
    import tagion.script.common : TagionBill;
    import tagion.testbench.services.sendcontract;
    import tagion.trt.TRT;
    import tagion.wallet.SecureWallet;

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
    const start_amount = 3000.TGN;

    // create the recorder
    SecureNet net = new StdSecureNet();
    net.generateKeyPair("very_secret");

    auto factory = RecordFactory(net);
    auto recorder = factory.recorder;
    recorder.insert(bills, Archive.Type.ADD);

    import tagion.tools.boot.genesis;
    import tagion.script.common;
    import tagion.hibon.Document;
    import tagion.hibon.BigNumber;
    import tagion.wave.mode0;

    const node_opts = getMode0Options(local_options, monitor: false);

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

    immutable neuewelle_args = ["send_contract_test", config_file]; // ~ args;

    auto tid = spawn(&wrap_neuewelle, neuewelle_args);

    Thread.sleep(5.seconds);
    writeln("going to run test");

    const task_name = "send_contract_tester";
    register(task_name, thisTid);
    log.registerSubscriptionTask(task_name);

    auto send_contract_feature = automation!(sendcontract);
    send_contract_feature.SendASingleTransactionFromAWalletToAnotherWallet(local_options, wallets, dart_interface_sock_addr, inputvalidator_sock_addr, start_amount);
    send_contract_feature.run();
    writefln("finished test execution");

    stopsignal.set;

    return 0;

}
