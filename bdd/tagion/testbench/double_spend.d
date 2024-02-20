module tagion.testbench.double_spend;

import core.thread;
import core.time;
import std.file;
import std.path : buildPath, setExtension;
import std.stdio;
import tagion.GlobalSignals;
import tagion.actor;
import tagion.basic.Types : FileExtension;
import tagion.behaviour.Behaviour;
import tagion.logger.Logger;
import tagion.services.options;
import tagion.testbench.services;
import tagion.testbench.services.double_spend;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import neuewelle = tagion.tools.neuewelle;
import tagion.utils.pretend_safe_concurrency;
import tagion.wave.mode0;

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
    local_options.wave.prefix_format = "DoubleSpend_Node_%s_";
    local_options.subscription.address = contract_sock_addr("DOUBLE_SPEND_SUBSCRIPTION");

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
    foreach (i; 0 .. 20) {
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

    TagionBill requestAndForce(ref StdSecureWallet w, TagionCurrency amount) {
        auto b = w.requestBill(amount);
        w.addBill(b);
        return b;
    }

    TagionBill[] bills;
    foreach (ref wallet; wallets) {
        foreach (i; 0 .. 3) {
            bills ~= requestAndForce(wallet, 1000.TGN);
        }
    }

    SecureNet net = new StdSecureNet();
    net.generateKeyPair("very_secret");

    auto factory = RecordFactory(net);
    auto recorder = factory.recorder;
    recorder.insert(bills, Archive.Type.ADD);

    import tagion.tools.boot.genesis;
    import tagion.script.common;
    import tagion.hibon.Document;
    import tagion.hibon.BigNumber;

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

    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        immutable prefix = format(local_options.wave.prefix_format, i);
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

    immutable neuewelle_args = [
        "double_spend", config_file
    ]; // ~ args;
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);

    writefln("INPUT SOCKET ADDRESS %s", node_opts[0].inputvalidator.sock_addr);

    Thread.sleep(10.seconds);
    auto name = "double_spend_testing";
    register(name, thisTid);
    log.registerSubscriptionTask(name);
    auto feature = automation!(double_spend);
    feature.SameInputsSpendOnOneContract(node_opts[0], wallets[0], wallets[1]);
    feature.OneContractWhereSomeBillsAreUsedTwice(node_opts[0], wallets[1], wallets[0]);
    feature.DifferentContractsDifferentNodes(node_opts[0], node_opts[1], wallets[2], wallets[3]);
    feature.SameContractDifferentNodes(node_opts[0], node_opts[1], wallets[4], wallets[5]);
    feature.SameContractInDifferentEpochs(node_opts[0], wallets[6], wallets[7]);
    feature.SameContractInDifferentEpochsDifferentNode(node_opts[2], node_opts[3], wallets[8], wallets[9]);
    feature.TwoContractsSameOutput(node_opts[3], node_opts[4], wallets[10], wallets[11], wallets[12]);
    feature.BillAge(node_opts[3], wallets[13], wallets[14]);
    feature.run();

    stopsignal.set;
    return 0;
}
