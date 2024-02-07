module tagion.testbench.e2e.transaction;
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
import std.format;

import tagion.tools.shell.shelloptions;
import tagion.tools.tagionshell : abort;
import tagion.services.options;
import std.process;

import tagion.testbench.e2e;

enum feature = Feature(
            "Send a contract through the shell",
            []);

alias FeatureContext = Tuple!(
        SendAContractWithOneOutputsThroughTheShell, "SendAContractWithOneOutputsThroughTheShell",
        FeatureGroup*, "result"
);

void wrap_shell(immutable(string[]) args) {
    import tagionshell = tagion.tools.tagionshell;
    tagionshell._main(cast(string[]) args);
}
void wrap_neuewelle(immutable(string)[] args) {
    neuewelle._main(cast(string[]) args);
}

mixin Main!(_main);
int _main(string[] args) {

    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) { rmdirRecurse(module_path); }
    mkdirRecurse(module_path);
    const shell_config_file = buildPath(module_path, "shell.json");
    const config_file = buildPath(module_path, "tagionwave.json");


    scope ShellOptions shell_opts = ShellOptions.defaultOptions;
    shell_opts.shell_uri = environment["SHELL_URI"];
    shell_opts.tagion_subscription_addr = contract_sock_addr(environment["SUBSCRIPTION"]);
    shell_opts.recorder_subscription_task_prefix = "TRANSACTION_Node_0_";
    shell_opts.mode0_prefix = environment["PREFIX"];
    shell_opts.save(shell_config_file);
    
    scope Options local_options = Options.defaultOptions;
    local_options.dart.folder_path = buildPath(module_path);
    local_options.trt.folder_path = buildPath(module_path);
    local_options.trt.enable = true;
    local_options.replicator.folder_path = buildPath(module_path, "recorders");
    local_options.epoch_creator.timeout = 250;
    local_options.wave.prefix_format = environment["PREFIX"];
    local_options.subscription.address = contract_sock_addr(environment["SUBSCRIPTION"]);
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
        foreach (i; 0 .. 1) {
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
        "transaction_test", config_file, "--nodeopts", module_path
    ]; 
    auto neuewelle_tid = spawn(&wrap_neuewelle, neuewelle_args);

    immutable(string[]) shell_args = ["tagionshell_transaction", shell_config_file];
    auto shell_tid = spawn(&wrap_shell, shell_args);

    Thread.sleep(20.seconds);
    
    auto feature = automation!(transaction);
    feature.SendAContractWithOneOutputsThroughTheShell(shell_opts, wallets[0], wallets[1]);
    feature.run;
    Thread.sleep(20.seconds);
    stopsignal.set;
    abort = true;
    Thread.sleep(5.seconds);
    return 0;
}

@safe @Scenario("send a contract with one outputs through the shell",
        [])
class SendAContractWithOneOutputsThroughTheShell {
    ShellOptions shell_opts;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;
    SignedContract signed_contract;
    TagionCurrency amount;
    TagionCurrency fee;
    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;


    string shell_addr;
    string bullseye_address;
    string dart_address;
    string contract_address;

    
    this(ShellOptions shell_opts, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.shell_opts = shell_opts;
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        shell_addr = shell_opts.shell_uri ~ shell_opts.shell_api_prefix;
        bullseye_address = shell_addr ~ shell_opts.bullseye_endpoint ~ ".hibon";
        dart_address = shell_addr ~ shell_opts.dart_endpoint ~ "/nocache";
        contract_address = shell_addr ~ shell_opts.contract_endpoint;
    }

    import nngd;
    @Given("i have a running network")
    Document network() {
        // we know the network is running since we get the bullseye
        return result_ok;
    }

    @Given("i have a running shell")
    Document shell() @trusted {
        import std.net.curl;

        writefln("BEFORE POST addr: %s", bullseye_address);
        immutable(ubyte[]) raw_res =cast(immutable) get!(AutoProtocol, ubyte)(bullseye_address);
        Document bullseye = Document(raw_res);
        writefln("hrep %s", bullseye.toPretty);
        auto receiver = wallet1_hirpc.receive(bullseye);
        check(receiver.isResponse, "should have received a bullseye response");
        return result_ok;
    }

    @When("i create a contract with all my bills")
    Document bills() {
        amount = wallet1.calcTotal(wallet1.account.bills) - 200.TGN;
        auto requested_bill = wallet2.requestBill(amount);
        auto payment = wallet1.createPayment([requested_bill], signed_contract, fee);

        const number_of_outputs = PayScript(signed_contract.contract.script).outputs.length;
        check(number_of_outputs == 1, format("should only have one output had %s", number_of_outputs));

        return result_ok;
    }

    @When("i send the contract")
    Document contract() @trusted {
        auto response = sendShellSubmitHiRPC(contract_address, wallet1_hirpc.submit(signed_contract), wallet1.net);
        check(!response.isError, format("Error when sending shell submit %s", response.toPretty));
        return result_ok;
    }

    @Then("the transaction should go through")
    Document through() @trusted {
        Thread.sleep(20.seconds);

        writefln("sending update to dartaddress %s", dart_address);
        auto wallet1_amount = getWalletInvoiceUpdateAmount(wallet1, dart_address, wallet1_hirpc, true);
        auto wallet2_amount = getWalletInvoiceUpdateAmount(wallet2, dart_address, wallet2_hirpc, true);


        check(wallet1_amount == 0.TGN, format("Should have zero tagions after sending all... had %s", wallet1_amount));
        auto wallet2_expected = start_amount2 + amount;
        check(wallet2_amount == wallet2_expected, format("should have %s had %s", wallet2_expected, wallet2_amount));
        return result_ok;
    }

}
