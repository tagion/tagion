module tagion.testbench.genesis_test;

import core.thread;
import core.time;
import std.file;
import std.path : buildPath, setExtension;
import std.stdio;
import std.conv;
import std.process : environment;
import tagion.GlobalSignals;
import tagion.actor;
import tagion.basic.Types : FileExtension;
import tagion.behaviour.Behaviour;
import tagion.logger.Logger;
import tagion.services.options;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import neuewelle = tagion.tools.neuewelle;
import tagion.utils.pretend_safe_concurrency;
import tagion.hibon.BigNumber;

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
    local_options.wave.number_of_nodes = 5;
    local_options.dart.folder_path = buildPath(module_path);
    local_options.trt.folder_path = buildPath(module_path);
    local_options.replicator.folder_path = buildPath(module_path, "recorders");
    local_options.wave.prefix_format = "Genesis_Node_%s_";
    // Don't start the subscription service because we want to use the test thread for subscription
    local_options.subscription.enable = false;
    local_options.save(config_file);

    import std.algorithm;
    import std.array;
    import std.format;
    import std.range;
    import std.stdio;
    import tagion.crypto.SecureInterfaceNet;
    import tagion.crypto.SecureNet;
    import tagion.dart.DART;
    import tagion.dart.DARTBasic;
    import tagion.dart.DARTFile;
    import tagion.dart.Recorder;
    import tagion.hibon.Document;
    import tagion.hibon.HiBON;
    import tagion.script.TagionCurrency;
    import tagion.script.common : TagionBill;
    import tagion.testbench.services.genesis_test;
    import tagion.trt.TRT;
    import tagion.wallet.SecureWallet;

    StdSecureWallet[] wallets;
    // create the wallets
    foreach (i; 0 .. 2) {
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
    BigNumber total_start_amount;
    foreach (ref wallet; wallets) {
        foreach (i; 0 .. 3) {
            auto bill = requestAndForce(wallet, 1000.TGN);
            bills ~= bill;
            total_start_amount += bill.value.units;
        }
    }

    SecureNet net = createSecureNet;
    net.generateKeyPair("very_secret");

    auto factory = RecordFactory(net.hash);
    auto recorder = factory.recorder;
    recorder.insert(bills, Archive.Type.ADD);

    // create the tagion head and genesis epoch
    import tagion.crypto.Types;
    import tagion.hibon.HiBON;
    import tagion.hibon.HiBONtoText;
    import tagion.script.common : GenesisEpoch, TagionGlobals, TagionHead;
    import tagion.script.standardnames;
    import tagion.utils.StdTime;

    // const total_amount = BigNumber(bills.map!(b => b.value).sum);
    const number_of_bills = long(bills.length);

    import tagion.wave.mode0;
    import tagion.tools.boot.genesis;
    import tagion.script.common;
    import tagion.hibon.Document;
    import tagion.hibon.BigNumber;

    const(Options)[] node_opts = getMode0Options(local_options);
    auto nets = dummy_nodenets_for_testing(node_opts);
    Pubkey[] keys = nets.map!(net => net.pubkey).array;
    NodeSettings[] node_settings;
    foreach (opt, key; zip(node_opts, keys)) {
        node_settings ~= NodeSettings(
                opt.task_names.epoch_creator, // Name
                key,
                opt.task_names.epoch_creator, // Address

                

        );
    }

    HiBON testamony = new HiBON;
    testamony["hola"] = "Hallo ich bin philip. VERY OFFICIAL TAGION GENESIS BLOCK; DO NOT ALTER IN ANY WAYS";

    auto globals = TagionGlobals(total_start_amount, BigNumber(0), number_of_bills, 0);
    /* const tagion_head = TagionHead(TagionDomain, 0); */
    /* writefln("total start_amount: %s, HEAD: %s \n genesis_epoch: %s", total_start_amount, tagion_head.toPretty, genesis_epoch */
    /*         .toPretty); */
    /**/
    /* recorder.add(tagion_head); */
    /* recorder.add(genesis_epoch); */

    /// FIXME: Duplicate generate genesis_epoch
    const genesis_epoch = GenesisEpoch(0, keys, Document(testamony), currentTime, globals);
    const genesis = createGenesis(
            node_settings,
            Document(testamony),
            globals,
    );

    recorder.insert(genesis, Archive.Type.ADD);

    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        immutable prefix = format(local_options.wave.prefix_format, i);
        const path = buildPath(local_options.dart.folder_path, prefix ~ local_options
                .dart.dart_filename);
        writeln("DART path: ", path);
        DARTFile.create(path, net.hash);
        auto db = new DART(net.hash, path);
        db.modify(recorder);
    }

    // Inisialize genesis TRT
    if (local_options.trt.enable) {
        auto trt_recorder = factory.recorder;
        genesisTRT(bills, trt_recorder, net.hash);

        foreach (i; 0 .. local_options.wave.number_of_nodes) {
            immutable prefix = format(local_options.wave.prefix_format, i);

            const trt_path = buildPath(local_options.trt.folder_path, prefix ~ local_options
                    .trt.trt_filename);
            writeln("TRT path: ", trt_path);
            DARTFile.create(trt_path, net.hash);
            auto trt_db = new DART(net.hash, trt_path);
            trt_db.modify(trt_recorder);
        }
    }

    immutable neuewelle_args = [
        "genesis_test", config_file
    ]; // ~ args;
    Tid tid = spawn(&wrap_neuewelle, neuewelle_args);
    string test_task_name = "genesis_testing";
    log.task_name = test_task_name;
    log.registerSubscriptionTask(test_task_name);

    Thread.sleep(15.seconds);

    auto feature = automation!(genesis_test);
    feature.NetworkRunningWithGenesisBlockAndEpochChain(node_opts, wallets[0], genesis_epoch);
    feature.run;

    stopsignal.setIfInitialized;
    return 0;
}
