module tagion.testbench.send_contract;
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
    import tagion.wallet.SecureWallet;
    import tagion.script.common : TagionBill;
    alias StdSecureWallet = SecureWallet!StdSecureNet;
    import tagion.script.TagionCurrency;

    StdSecureWallet[] wallets;
    // create the wallets
    foreach(i; 0..10) {
        StdSecureWallet secure_wallet;
        secure_wallet = StdSecureWallet.createWallet(
            iota(0,5).map!(n => format("%dquestion%d", i, n)).array,
            iota(0,5).map!(n => format("%danswer%d", i, n)).array,
            4,
            format("%04d", i),
        );
        wallets ~= secure_wallet;
    }

    TagionBill[] bills;
    // bills for the dart
    foreach(wallet; wallets) {
        auto bill = wallet.requestBill(1000.TGN);
        bills ~= bill;
    }

    writeln(bills);




    

    immutable neuewelle_args = [config_file];
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);
    Thread.sleep(10.seconds);

    auto send_contract_feature = automation!(sendcontract);
    send_contract_feature.run();


    import tagion.hibon.HiBONRecord;
    import tagion.hibon.HiBONRecord;


    stopsignal.set;

    return 0;

}
