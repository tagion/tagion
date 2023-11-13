module tagion.testbench.genesis_test;

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
    local_options.wave.prefix_format = "Genesis Node_%s_";
    local_options.subscription.address = contract_sock_addr("GENESIS_SUBSCRIPTION");
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
    foreach (i; 0 .. 3) {
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
    long __VERY_UGLY;
    foreach (ref wallet; wallets) {
        foreach (i; 0 .. 3) {
            bills ~= requestAndForce(wallet, 1000.TGN);
            __VERY_UGLY += 1000;

        }
    }

    SecureNet net = new StdSecureNet();
    net.generateKeyPair("very_secret");

    auto factory = RecordFactory(net);
    auto recorder = factory.recorder;
    recorder.insert(bills, Archive.Type.ADD);

    // create the tagion head and genesis epoch
    import tagion.crypto.Types;
    import tagion.hibon.BigNumber;
    import tagion.hibon.HiBON;
    import tagion.hibon.HiBONtoText;
    import tagion.script.common : GenesisEpoch, TagionGlobals, TagionHead;
    import tagion.script.standardnames;
    import tagion.utils.StdTime;

    // const total_amount = BigNumber(bills.map!(b => b.value).sum);
    const total_amount = BigNumber(__VERY_UGLY);
    const number_of_bills = long(bills.length);


    const globals = TagionGlobals(total_amount, const BigNumber(0), number_of_bills, const long(0));

    const tagion_head = TagionHead(TagionDomain, 0, globals);
    writefln("CREATED TAGION HEAD: %s", tagion_head.toDoc.encodeBase64);

    Pubkey[] keys;
    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        auto _net = new StdSecureNet();
        const pswd = format(local_options.wave.prefix_format, i) ~ "supervisor";
        writefln("bdd: %s", pswd);
        _net.generateKeyPair(pswd);
        keys ~= _net.pubkey;
        writefln("pkey: %s", _net.pubkey.encodeBase64);
    }

    HiBON testamony = new HiBON;
    testamony["hola"] = "Hallo ich bin philip. VERY OFFICIAL TAGION GENESIS BLOCK; DO NOT ALTER IN ANY WAYS";
    const genesis_epoch = GenesisEpoch(0, keys, Document(testamony), currentTime);

    recorder.add(tagion_head);
    recorder.add(genesis_epoch);

    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        immutable prefix = format(local_options.wave.prefix_format, i);
        const path = buildPath(local_options.dart.folder_path, prefix ~ local_options.dart.dart_filename);
        writeln(path);
        DARTFile.create(path, net);
        auto db = new DART(net, path);
        db.modify(recorder);
    }

    immutable neuewelle_args = ["genesis_test", config_file, "--nodeopts", module_path]; // ~ args;
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);

    import tagion.utils.JSONCommon : load;

    Options[] node_opts;

    Thread.sleep(10.seconds);
    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        const filename = buildPath(module_path, format(local_options.wave.prefix_format ~ "opts", i).setExtension(FileExtension
                .json));
        writeln(filename);
        Options node_opt = load!(Options)(filename);
        node_opts ~= node_opt;
    }

    auto name = "genesis_testing";
    register(name, thisTid);
    log.registerSubscriptionTask(name);

    writefln("INPUT SOCKET ADDRESS %s", node_opts[0].inputvalidator.sock_addr);

    auto feature = automation!(genesis_test);
    feature.run;

    feature.run;
    Thread.sleep(15.seconds);

    stopsignal.set;
    Thread.sleep(6.seconds);
    return 0;
}
