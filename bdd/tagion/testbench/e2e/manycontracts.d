module tagion.testbench.e2e.manycontracts;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.tools.Basic;

import std.format;
import std.algorithm;
import std.range;
import std.stdio;
import std.path;

import tagion.tools.wallet.WalletOptions : WalletOptions;
import tagion.tools.wallet.WalletInterface : WalletInterface;
import tagion.script.common;
import tagion.script.TagionCurrency;

enum feature = Feature(
        "send multiple contracts through the network",
        []);

alias FeatureContext = Tuple!(
    SendNContractsFromwallet1Towallet2, "SendNContractsFromwallet1Towallet2",
    FeatureGroup*, "result"
);

@safe @Scenario("send N contracts from `wallet1` to `wallet2`",
    [])
class SendNContractsFromwallet1Towallet2
{
    WalletInterface[] wallets;

    this(WalletInterface[] wallets) {
        this.wallets = wallets;
    }

    @Given("i have a network")
    Document network() @trusted
    {
        auto wallet_switch = WalletInterface.Switch(update: true, sendkernel: true);

        foreach(ref w; wallets) {
            w.operate(wallet_switch, []);
        }

        return result_ok;
    }

    @When("i send N many valid contracts from `wallet1` to `wallet2`")
    Document wallet2()
    {
        const invoice = wallets[0].secure_wallet.createInvoice("Invoice", 1000.TGN);

        SignedContract s_contract;
        TagionCurrency fees;
        auto result = wallets[1].secure_wallet.payment([invoice], s_contract, fees);
        result.get;

        return result_ok;
    }

    @When("all the contracts have been executed")
    Document executed()
    {
        return Document();
    }

    @Then("wallet1 and wallet2 balances should be updated")
    Document updated()
    {
        return Document();
    }

}

alias manycontracts = tagion.testbench.e2e.manycontracts;

mixin Main!(_main);

// import std.range;
// import std.path : setExtension, buildPath;
// import std.algorithm;
// import std.stdio;
// import std.format;
// import std.file : mkdirRecurse, exists, rmdirRecurse;
// import core.time : seconds;
// 
// import tagion.wallet.SecureWallet;
// import tagion.services.options;
// import tagion.services.supervisor: SupervisorHandle;
// import tagion.dart.Recorder;
// import tagion.dart.DARTBasic;
// import tagion.dart.DARTFile;
// import tagion.dart.DART;
// import tagion.crypto.SecureNet : StdSecureNet;
// import tagion.crypto.SecureInterfaceNet;
// import tagion.script.common : TagionBill;
// import tagion.script.TagionCurrency;
// import tagion.testbench.tools.Environment;
// import tagion.actor;
// 
// alias StdSecureWallet = SecureWallet!StdSecureNet;

version(none)
int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);

    import tagion.tools.neuewelle;

    StdSecureWallet[] wallets;
    // create the wallets
    foreach (i; 0 .. 2) {
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
    foreach (_; 0 .. 100) {
        bills ~= wallets[0].requestBill(1000.TGN);
    }

    // create the recorder
    SecureNet net = new StdSecureNet();
    net.generateKeyPair("very_secret");

    auto factory = RecordFactory(net);
    auto recorder = factory.recorder;
    recorder.insert(bills, Archive.Type.ADD);

    // string dart_interface_sock_addr;
    // string inputvalidator_sock_addr;

    auto local_options = Options();
    local_options.setDefault;
    local_options.dart.folder_path = buildPath(env.bdd_log, __MODULE__);
    if (local_options.dart.folder_path.exists) {
        rmdirRecurse(local_options.dart.folder_path);
    }
    mkdirRecurse(local_options.dart.folder_path);

    auto all_node_options = get_mode_0_options(local_options);
    // create the databases
    foreach (opt; all_node_options) {
        const path = buildPath(opt.dart.folder_path, opt.dart.dart_filename);
        writeln(path);
        DARTFile.create(path, net);
        auto db = new DART(net, path);
        db.modify(recorder);
    }

    SupervisorHandle[] handles;
    network_mode0(all_node_options, handles);

    waitforChildren(Ctrl.ALIVE, 15.seconds);

    auto manycontracts_feature = automation!manycontracts;
    manycontracts_feature.run;

    while(true){
    }

    return 0;
}

import std.getopt;
import std.file;

int _main(string[] args) {
    const program = args[0];
    string[] wallet_config_files;
    string[] wallet_pins;

    arraySep = ",";
    auto main_args = getopt(args,
            "w", "wallet config files", &wallet_config_files,
            "x", "wallet pins", &wallet_pins,
            // "n", "network config file", &network_config,
    );

    if (main_args.helpWanted) {
        defaultGetoptPrinter(
                [
                "Usage:",
                format("%s [<option>...] <config.json> <files>", program),
                "<option>:",
                ].join("\n"),
                main_args.options);
        return 0;
    }

    import std.process : environment;
    const HOME = environment.get("HOME");
    if(wallet_config_files.empty) {
        wallet_config_files = dirEntries(buildPath(HOME, ".local/share/tagion/wallets/"), "wallet*.json", SpanMode.shallow).map!(a => a.name).array.sort.array;
        if(wallet_config_files.empty) {
            writeln("No wallet configs available");
            return 0;
        }
    }

    if(wallet_pins.empty) {
        foreach(i, _; wallet_config_files) {
            wallet_pins ~= format("%04d", i+1);
        }
    }

    check(wallet_pins.length == wallet_config_files.length, "wallet configs and wallet pins were not the same amount");

    WalletOptions[] wallet_options;
    WalletInterface[] wallet_interfaces;
    foreach(i, c; wallet_config_files) {
        WalletOptions opts;
        opts.load(c);
        wallet_options ~= opts;
        auto wallet_interface = WalletInterface(opts);
        check(wallet_interface.load, "Wallet %s could not be loaded".format(i));
        check(wallet_interface.secure_wallet.login(wallet_pins[i]), "Wallet %s, %s, %s not logged in".format(i, wallet_pins[i], c));
        wallet_interfaces ~= wallet_interface;
        writefln("Wallet logged in %s", wallet_interface.secure_wallet.isLoggedin);
    }

    auto manycontracts_feature = automation!manycontracts;
    manycontracts_feature.SendNContractsFromwallet1Towallet2(wallet_interfaces);
    manycontracts_feature.run;
    return 1;
}
