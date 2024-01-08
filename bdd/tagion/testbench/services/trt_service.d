module tagion.testbench.services.trt_service;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import std.file;
import std.path : buildPath, setExtension;
import tagion.GlobalSignals;
import tagion.basic.Types : FileExtension;
import std.stdio;
import tagion.behaviour.Behaviour;
import tagion.services.options;
import tagion.testbench.services;
import tagion.tools.Basic;
import neuewelle = tagion.tools.neuewelle;
import tagion.utils.pretend_safe_concurrency;
import core.thread;
import core.time;
import tagion.logger.Logger;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.communication.HiRPC;
import tagion.testbench.services.sendcontract;
import tagion.wallet.SecureWallet;
import tagion.testbench.services.helper_functions;
import tagion.behaviour.BehaviourException : check;
import tagion.tools.wallet.WalletInterface;

enum CONTRACT_TIMEOUT = 40;
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
    local_options.trt.enable = true;
    local_options.replicator.folder_path = buildPath(module_path, "recorders");
    local_options.epoch_creator.timeout = 500;
    local_options.wave.prefix_format = "TRT_TEST_Node_%s_";
    local_options.subscription.address = contract_sock_addr("TRT_TEST_SUBSCRIPTION");
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
    import tagion.trt.TRT;

    auto trt_recorder = factory.recorder;
    genesisTRT(bills, trt_recorder, net);

    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        immutable prefix = format(local_options.wave.prefix_format, i);
        const path = buildPath(local_options.dart.folder_path, prefix ~ local_options
                .dart.dart_filename);
        const trt_path = buildPath(local_options.trt.folder_path, prefix ~ local_options
                .trt.trt_filename);
        // writeln(path);
        // writeln(trt_path);
        DARTFile.create(path, net);
        DARTFile.create(trt_path, net);
        auto db = new DART(net, path);
        auto trt_db = new DART(net, trt_path);
        db.modify(recorder);
        trt_db.modify(trt_recorder);

        writefln("%s TRT bullseye: %(%02x%)", trt_path, trt_db.bullseye);
        writefln("%s DART bullseye: %(%02x%)", path, db.bullseye);

        db.close;
        trt_db.close;
    }

    immutable neuewelle_args = [
        "trt_test", config_file, "--nodeopts", module_path
    ]; // ~ args;
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);
    import tagion.utils.JSONCommon : load;

    Options[] node_opts;

    Thread.sleep(15.seconds);
    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        const filename = buildPath(module_path, format(local_options.wave.prefix_format ~ "opts", i).setExtension(
                FileExtension
                .json));
        writeln(filename);
        Options node_opt = load!(Options)(filename);
        node_opts ~= node_opt;
    }
    auto name = "trt_testing";
    register(name, thisTid);
    log.registerSubscriptionTask(name);

    Thread.sleep(10.seconds);

    auto feature = automation!(trt_service);
    feature.SendAInoiceUsingTheTRT(node_opts[0], wallets[0], wallets[1]);

    feature.run;

    stopsignal.set;
    Thread.sleep(6.seconds);

    return 0;

}

enum feature = Feature(
        "TRT Service test",
        []);

alias FeatureContext = Tuple!(
    SendAInoiceUsingTheTRT, "SendAInoiceUsingTheTRT",
    FeatureGroup*, "result"
);

@safe @Scenario("send a inoice using the TRT",
    [])
class SendAInoiceUsingTheTRT {
    Options opts1;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    //
    SignedContract signed_contract1;
    SignedContract signed_contract2;
    TagionCurrency amount;
    TagionCurrency fee1;
    TagionCurrency fee2;

    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;
    this(Options opts1, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts1 = opts1;

        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);

    }

    @Given("i have a running network with a trt")
    Document trt() {
        writefln("address to dial %s", opts1.dart_interface.sock_addr);
        auto wallet1_amount = getWalletInvoiceUpdateAmount(wallet1, opts1.dart_interface.sock_addr, wallet1_hirpc);
        check(wallet1_amount == start_amount1, "balance should not have changed");
        auto wallet2_amount = getWalletInvoiceUpdateAmount(wallet2, opts1.dart_interface.sock_addr, wallet2_hirpc);
        check(wallet2_amount == start_amount2, "balance should not have changed");
        // create a update request
        return result_ok;
    }

    @When("i create and send a invoice")
    Document invoice() {
        amount = 100.TGN;
        auto invoice_to_pay = wallet2.createInvoice("wowo", amount);
        wallet2.registerInvoice(invoice_to_pay);
        wallet1.payment([invoice_to_pay], signed_contract1, fee1);
        (() @trusted => Thread.sleep(1.seconds))();
        wallet1.payment([invoice_to_pay], signed_contract2, fee2);

        sendSubmitHiRPC(opts1.inputvalidator.sock_addr, wallet1_hirpc.submit(signed_contract1), wallet1
                .net);
        sendSubmitHiRPC(opts1.inputvalidator.sock_addr, wallet1_hirpc.submit(signed_contract2), wallet1
                .net);
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();
        return result_ok;
    }

    @When("i update my wallet using the pubkey lookup")
    Document lookup() {
        import std.format;

        auto wallet1_amount = getWalletInvoiceUpdateAmount(wallet1, opts1.dart_interface.sock_addr, wallet1_hirpc);
        auto wallet2_amount = getWalletInvoiceUpdateAmount(wallet2, opts1.dart_interface.sock_addr, wallet2_hirpc);

        auto wallet1_expected = start_amount1 - fee1 - fee2 - 2 * amount;
        check(wallet1_amount == wallet1_expected, format("should have %s had %s", wallet1_expected, wallet1_amount));
        auto wallet2_expected = start_amount2 + 2 * amount;
        check(wallet2_amount == wallet2_expected, format("should have %s had %s", wallet2_expected, wallet2_amount));

        return result_ok;
    }

    @Then("the transaction should go through")
    Document through() {
        return result_ok;
    }

}
