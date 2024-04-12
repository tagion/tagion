module bdd.tagion.testbench.testtools.dartutil_test;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

////////////////////////////////
import std.file;
import std.path : buildPath, setExtension;
import tagion.GlobalSignals;
import tagion.basic.Types : FileExtension;
import std.stdio;
import tagion.behaviour.Behaviour;
import tagion.services.options;
import tagion.testbench.testtools;
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
import tagion.wallet.request;
import tagion.testbench.services.helper_functions;
import tagion.behaviour.BehaviourException : check;
import tagion.tools.wallet.WalletInterface;

////////////////////////////////

import tagion.dart.Recorder;
import tagion.crypto.SecureNet;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.hibon.Document;

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
    // string config_file = buildPath(module_path, "tagionwave.json");

    // scope Options local_options = Options.defaultOptions;
    // local_options.dart.folder_path = buildPath(module_path);
    // local_options.trt.folder_path = buildPath(module_path);
    // local_options.trt.enable = true;
    // local_options.replicator.folder_path = buildPath(module_path, "recorders");
    // local_options.epoch_creator.timeout = 500;
    // local_options.wave.prefix_format = "TRT_TEST_Node_%s_";
    // local_options.subscription.address = contract_sock_addr("TRT_TEST_SUBSCRIPTION");
    // local_options.save(config_file);

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

    // StdSecureWallet[] wallets;
    // // create the wallets
    // foreach (i; 0 .. 5) {
    //     StdSecureWallet secure_wallet;
    //     secure_wallet = StdSecureWallet(
    //         iota(0, 5)
    //             .map!(n => format("%dquestion%d", i, n)).array,
    //             iota(0, 5)
    //             .map!(n => format("%danswer%d", i, n)).array,
    //             4,
    //             format("%04d", i),
    //     );
    //     wallets ~= secure_wallet;
    // }

    // TagionBill requestAndForce(ref StdSecureWallet w, TagionCurrency amount) {
    //     auto b = w.requestBill(amount);
    //     w.addBill(b);
    //     return b;
    // }

    // TagionBill[] bills;
    // foreach (ref wallet; wallets) {
    //     foreach (i; 0 .. 3) {
    //         bills ~= requestAndForce(wallet, 1000.TGN);
    //     }
    // }

    // SecureNet net = new StdSecureNet();
    // net.generateKeyPair("very_secret");

    // auto factory = RecordFactory(net);
    // auto recorder = factory.recorder;
    // recorder.insert(bills, Archive.Type.ADD);

    // import tagion.tools.boot.genesis;
    // import tagion.script.common;
    // import tagion.hibon.Document;
    // import tagion.hibon.BigNumber;
    // import tagion.wave.mode0;

    // const node_opts = getMode0Options(local_options);

    // NodeSettings[] node_settings;
    // auto nodenets = dummy_nodenets_for_testing(node_opts);
    // foreach (opt, node_net; zip(node_opts, nodenets)) {
    //     node_settings ~= NodeSettings(
    //         opt.task_names.epoch_creator, // Name
    //         node_net.pubkey,
    //         opt.task_names.epoch_creator, // Address

    //     );
    // }

    // const genesis = createGenesis(
    //     node_settings,
    //     Document(),
    //     TagionGlobals(BigNumber(bills.map!(a => a.value.units).sum), BigNumber(0), bills.length, 0)
    // );

    // recorder.insert(genesis, Archive.Type.ADD);

    // import tagion.trt.TRT;

    // auto trt_recorder = factory.recorder;
    // genesisTRT(bills, trt_recorder, net);

    // foreach (i; 0 .. local_options.wave.number_of_nodes) {
    //     immutable prefix = format(local_options.wave.prefix_format, i);
    //     const path = buildPath(local_options.dart.folder_path, prefix ~ local_options
    //             .dart.dart_filename);
    //     const trt_path = buildPath(local_options.trt.folder_path, prefix ~ local_options
    //             .trt.trt_filename);
    //     // writeln(path);
    //     // writeln(trt_path);
    //     DARTFile.create(path, net);
    //     DARTFile.create(trt_path, net);
    //     auto db = new DART(net, path);
    //     auto trt_db = new DART(net, trt_path);
    //     db.modify(recorder);
    //     trt_db.modify(trt_recorder);

    //     writefln("%s TRT bullseye: %(%02x%)", trt_path, trt_db.bullseye);
    //     writefln("%s DART bullseye: %(%02x%)", path, db.bullseye);

    //     db.close;
    //     trt_db.close;
    // }

    // immutable neuewelle_args = [
    //     "trt_test", config_file
    // ]; // ~ args;
    // auto tid = spawn(&wrap_neuewelle, neuewelle_args);

    auto name = "dartutil_test";
    register(name, thisTid);
    log.registerSubscriptionTask(name);

    Thread.sleep(10.seconds);

    auto feature = automation!(dartutil_test);
    feature.Bullseye(module_path);
    feature.run;

    stopsignal.set;
    Thread.sleep(6.seconds);

    return 0;

}

enum feature = Feature(
        "dartutil scenarios",
        []);

alias FeatureContext = Tuple!(
    Bullseye, "Bullseye",
    FeatureGroup*, "result"
);

@safe @Scenario("Bullseye",
    [])
class Bullseye {
    string dart_path;

    this(string module_path) {
        // this.module_path = module_path;
        this.dart_path = module_path ~ "/dartutil_test.drt";
        writefln("dartutil DART path: %s", this.dart_path);
    }

    @Given("initial dart file")
    Document dartFile() {
        SecureNet net = new StdSecureNet();
        net.generateKeyPair("very_secret");

        // const genesis_node_settings = mk_node_settings(node_opts);
        // const genesis_doc = createGenesis(genesis_node_settings, Document(), TagionGlobals.init);

        auto factory = RecordFactory(net);
        auto recorder = factory.recorder;

        HiBON hibon = new HiBON;
        hibon["a"] = 42;
        recorder.insert(Document(hibon), Archive.Type.ADD);

        DARTFile.create(dart_path, net);
        auto db = new DART(net, dart_path);
        db.modify(recorder);

        return result_ok;
    }

    @When("dartutil is called with given input file")
    Document inputFile() {
        return result_ok;
    }

    @Then("the bullseye should be as expected")
    Document asExpected() {
        return result_ok;
    }
}
