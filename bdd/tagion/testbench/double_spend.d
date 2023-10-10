module tagion.testbench.double_spend;

import tagion.tools.Basic;
import tagion.behaviour.Behaviour;
import tagion.testbench.services;
import tagion.testbench.tools.Environment;
import std.file;

import std.path : setExtension, buildPath;
import tagion.basic.Types : FileExtension;

import tagion.services.options;
import core.time;
import core.thread;
import std.stdio;

import neuewelle = tagion.tools.neuewelle;

import tagion.utils.pretend_safe_concurrency;
import tagion.GlobalSignals;
import tagion.testbench.services.double_spend;

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
    local_options.replicator.folder_path = buildPath(module_path);
    local_options.save(config_file);

    import std.format;
    import std.range;
    import std.array;
    import std.algorithm;
    import std.stdio;
    import tagion.crypto.SecureNet : StdSecureNet;
    import tagion.crypto.SecureInterfaceNet;
    import tagion.dart.DARTFile;
    import tagion.dart.DART;
    import tagion.wallet.SecureWallet;
    import tagion.script.common : TagionBill;
    import tagion.testbench.services.sendcontract;
    import tagion.script.TagionCurrency;
    import tagion.dart.Recorder;

    StdSecureWallet[] wallets;
    // create the wallets
    foreach (i; 0 .. 5) {
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
    TagionBill[] bills;
    foreach (ref wallet; wallets) {
        bills ~= wallet.requestBill(1000.TGN);
        bills ~= wallet.requestBill(2000.TGN);
    }

    SecureNet net = new StdSecureNet();
    net.generateKeyPair("very_secret");

    auto factory = RecordFactory(net);
    auto recorder = factory.recorder;
    recorder.insert(bills, Archive.Type.ADD);

    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        immutable prefix = format(local_options.wave.prefix_format, i);
        const path = buildPath(local_options.dart.folder_path, prefix ~ local_options.dart.dart_filename);
        writeln(path);
        DARTFile.create(path, net);
        auto db = new DART(net, path);
        db.modify(recorder);
    }

    immutable neuewelle_args = ["send_contract_test", config_file, "--nodeopts", module_path]; // ~ args;
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);
    Thread.sleep(15.seconds);

    neuewelle.signal_handler(0);
    return 0;
}

