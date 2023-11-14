module tagion.testbench.malformed_contract;

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
    local_options.replicator.folder_path = buildPath(module_path, "recorders");
    local_options.wave.prefix_format = "Malformed Contract Node_%s_";
    local_options.subscription.address = contract_sock_addr("MALFORMED_SUBSCRIPTION");

    local_options.save(config_file);

    import std.algorithm;
    import std.array;
    import std.format;
    import std.range;
    import std.stdio;
    import tagion.crypto.SecureInterfaceNet;
    import tagion.crypto.SecureNet : StdSecureNet;
    import tagion.dart.DART;
    import tagion.dart.DARTBasic;
    import tagion.dart.DARTFile;
    import tagion.dart.Recorder;
    import tagion.hibon.Document;
    import tagion.hibon.HiBON;
    import tagion.script.TagionCurrency;
    import tagion.script.common : TagionBill;
    import tagion.testbench.services.sendcontract;
    import tagion.wallet.SecureWallet;

    StdSecureWallet[] wallets;
    // create the wallets
    foreach (i; 0 .. 20) {
        StdSecureWallet secure_wallet;
        secure_wallet = StdSecureWallet(
                iota(0, 5).map!(n => format("%dquestion%d", i, n)).array,
                iota(0, 5).map!(n => format("%danswer%d", i, n)).array,
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

    // put a random archive in that is not a bill.

    auto random_data = new HiBON;
    random_data["wowo"] = "test";

    const random_doc = Document(random_data);
    recorder.insert(random_doc, Archive.Type.ADD);

    immutable(DARTIndex) random_fingerprint = wallets[0].net.dartIndex(random_doc);
    writefln("RANDOM FINGERPRINT %(%02x%)", random_fingerprint);

    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        immutable prefix = format(local_options.wave.prefix_format, i);
        const path = buildPath(local_options.dart.folder_path, prefix ~ local_options.dart.dart_filename);
        writeln(path);
        DARTFile.create(path, net);
        auto db = new DART(net, path);
        db.modify(recorder);
    }

    immutable neuewelle_args = ["malformed_contract_test", config_file, "--nodeopts", module_path]; // ~ args;
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);

    import tagion.utils.JSONCommon : load;

    Options[] node_opts;

    Thread.sleep(5.seconds);
    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        const filename = buildPath(module_path, format(local_options.wave.prefix_format ~ "opts", i).setExtension(FileExtension
                .json));
        writeln(filename);
        Options node_opt = load!(Options)(filename);
        node_opts ~= node_opt;
    }

    auto name = "malformed_testing";
    register(name, thisTid);
    log.registerSubscriptionTask(name);

    writefln("INPUT SOCKET ADDRESS %s", node_opts[0].inputvalidator.sock_addr);

    auto feature = automation!(malformed_contract);
    feature.ContractTypeWithoutCorrectInformation(node_opts[0], wallets[0]);
    auto feature_context = feature.run;


    bool epoch_on_startup = feature_context[0].epoch_on_startup;

    feature.InputsAreNotBillsInDart(node_opts[1], wallets[1], random_doc, epoch_on_startup);
    feature.NegativeAmountAndZeroAmountOnOutputBills(node_opts[2], wallets[2], epoch_on_startup);
    feature.ContractWhereInputIsSmallerThanOutput(node_opts[3], wallets[3], epoch_on_startup);

    feature.run;
    Thread.sleep(15.seconds);

    stopsignal.set;
    Thread.sleep(6.seconds);
    return 0;
}
