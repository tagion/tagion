module tagion.testbench.services.big_contract;
// Default import list for bdd
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
import tagion.utils.pretend_safe_concurrency;
import neuewelle = tagion.tools.neuewelle;
import tagion.communication.HiRPC;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.hibon.Document;
import tagion.testbench.services.sendcontract : StdSecureWallet;
import tagion.behaviour;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.behaviour;
import tagion.behaviour.BehaviourException : check;
import tagion.tools.wallet.WalletInterface;
import std.format;
import tagion.wallet.SecureWallet;
import tagion.testbench.services.helper_functions;

mixin Main!(_main);

void wrap_neuewelle(immutable(string)[] args) {
    neuewelle._main(cast(string[]) args);
}

enum CONTRACT_TIMEOUT = 40;
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
    local_options.wave.prefix_format = "BigContract_Node_%s_";
    local_options.subscription.address = contract_sock_addr("BIG_CONTRACT_SUBSCRIPTION");
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
    import tagion.hibon.HiBON;
    import tagion.trt.TRT;

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

    TagionBill requestAndForce(ref StdSecureWallet w, TagionCurrency amount) {
        auto b = w.requestBill(amount);
        w.addBill(b);
        return b;
    }

    TagionBill[] bills;
    auto bill = requestAndForce(wallets[0], 1000_000_000.TGN);
    bills ~= bill;

    SecureNet net = new StdSecureNet();
    net.generateKeyPair("very_secret");

    auto factory = RecordFactory(net);
    auto recorder = factory.recorder;
    recorder.insert(bills, Archive.Type.ADD);

    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        immutable prefix = format(local_options.wave.prefix_format, i);
        const path = buildPath(local_options.dart.folder_path, prefix ~ local_options
                .dart.dart_filename);
        writeln("DART path: ", path);
        DARTFile.create(path, net);
        auto db = new DART(net, path);
        db.modify(recorder);
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
        "big_contract", config_file, "--nodeopts", module_path
    ]; // ~ args;
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);
    import tagion.utils.JSONCommon : load;

    Options[] node_opts;

    Thread.sleep(5.seconds);
    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        const filename = buildPath(module_path, format(local_options.wave.prefix_format ~ "opts", i).setExtension(
                FileExtension
                .json));
        writeln(filename);
        Options node_opt = load!(Options)(filename);
        node_opts ~= node_opt;
    }
    Thread.sleep(15.seconds);
    auto name = "big_contract_testing";
    register(name, thisTid);
    log.registerSubscriptionTask(name);

    writefln("BEFORE RUNNING TESTS");
    auto feature = automation!(big_contract);
    feature.SendASingleTransactionFromAWalletToAnotherWalletWithManyOutputs(
        node_opts[0], wallets[0], wallets[1]);
    feature.run;
    stopsignal.set;
    Thread.sleep(6.seconds);
    return 0;

}

enum feature = Feature(
        "send a contract with many outputs to the network.",
        []);

alias FeatureContext = Tuple!(
    SendASingleTransactionFromAWalletToAnotherWalletWithManyOutputs, "SendASingleTransactionFromAWalletToAnotherWalletWithManyOutputs",
    FeatureGroup*, "result"
);

@safe @Scenario("send a single transaction from a wallet to another wallet with many outputs.",
    [])
class SendASingleTransactionFromAWalletToAnotherWalletWithManyOutputs {
    Options opts1;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    //
    SignedContract signed_contract1;
    TagionCurrency amount;
    TagionCurrency fee;
    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;
    const req_amount = 1000.TGN;
    TagionBill[] bills;

    this(Options opts1, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts1 = opts1;

        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        writefln("bills length: %s", wallet1.account.bills.length);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
    }

    @Given("i have a dart database with already existing bills liked to wallet1")
    Document _wallet1() {
        writefln("wowo");
        return result_ok;
    }

    @Given("i make multiple payment requests in wallet2")
    Document _wallet2() {

        writeln("requesting bill");
        (() @trusted => stdout.flush)();

        foreach (i; 0 .. 69) {
            auto payment_request = wallet2.requestBill(req_amount);
            bills ~= payment_request;
        }

        check(wallet1.createPayment(bills, signed_contract1, fee).value, "error creating payment");
        // writefln("signedcontract %s", signed_contract1.toPretty);
        return result_ok;
    }

    @When("i pay all of the requests from wallet2 and send it to the network")
    Document network() {

        auto contract = wallet1_hirpc.submit(signed_contract1);
        writefln("contract: %s", contract.toPretty);
        writefln("contract: %(%02x%)", contract.toDoc.serialize);
        writefln("CONTRACT size %d", contract.toDoc.full_size);
        sendSubmitHiRPC(opts1.inputvalidator.sock_addr, contract, wallet1_hirpc);
        return result_ok;
    }

    @Then("the contract should go through")
    Document through() {
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();

        auto wallet1_amount = getWalletUpdateAmount(wallet1, opts1.dart_interface.sock_addr, wallet1_hirpc);
        auto wallet2_amount = getWalletUpdateAmount(wallet2, opts1.dart_interface.sock_addr, wallet2_hirpc);
        writefln("WALLET 1: %s, WALLET 2: %s", wallet1_amount, wallet2_amount);
        const wallet1_expected = start_amount1 - wallet1.calcTotal(bills) - fee;
        check(wallet1_amount == wallet1_expected, format("Wallet1 should have %s had %s", wallet1_expected, wallet1_amount));
        const wallet2_expected = start_amount2 + wallet1.calcTotal(bills);
        check(wallet2_amount == wallet2_expected, format("Wallet2 should have %s had %s", wallet2_expected, wallet2_amount));
        return result_ok;
    }

}
