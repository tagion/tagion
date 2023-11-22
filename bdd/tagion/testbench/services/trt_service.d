module tagion.testbench.services.trt_service;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import std.file;
import std.path : buildPath, setExtension;
import std.stdio;
import tagion.behaviour.Behaviour;
import tagion.services.options;
import tagion.testbench.services;
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
    local_options.trt.folder_path = buildPath(module_path);
    local_options.replicator.folder_path = buildPath(module_path, "recorders");
    local_options.epoch_creator.timeout = 500;
    local_options.wave.prefix_format = "TRT TEST Node_%s_";
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
    import tagion.script.TagionCurrency;
    import tagion.script.common : TagionBill;
    import tagion.testbench.services.sendcontract;
    import tagion.wallet.SecureWallet;
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
        const path = buildPath(local_options.dart.folder_path, prefix ~ local_options.dart.dart_filename);
        const trt_path = buildPath(local_options.trt.folder_path, prefix ~ local_optins.trt.trt_filename);
        writeln(path);
        DARTFile.create(path, net);
        DARTFile.create(trt_path, net);
        auto db = new DART(net, path);
        auto trt_db = new DART(net, path);
        db.modify(recorder);
        trt_db.modify(trt_recorder);
        db.close;
        trt_db.close;
    }

    immutable neuewelle_args = ["spam_double_spend_test", config_file, "--nodeopts", module_path]; // ~ args;
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);
    import tagion.utils.JSONCommon : load;

    Options[] node_opts;

    Thread.sleep(15.seconds);
    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        const filename = buildPath(module_path, format(local_options.wave.prefix_format ~ "opts", i).setExtension(FileExtension
                .json));
        writeln(filename);
        Options node_opt = load!(Options)(filename);
        node_opts ~= node_opt;
    }
    auto feature = automation!(trt_service);

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

    @Given("i have a running network with a trt")
    Document trt() {
        return Document();
    }

    @When("i create and send a invoice")
    Document invoice() {
        return Document();
    }

    @When("i update my wallet using the pubkey lookup")
    Document lookup() {
        return Document();
    }

    @Then("the transaction should go through")
    Document through() {
        return Document();
    }

}
