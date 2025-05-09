module tagion.testbench.e2e.run_epochs;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;
import tagion.testbench.e2e;
import std.file;
import std.path : buildPath, setExtension;
import tagion.GlobalSignals;
import tagion.basic.Types : FileExtension;
import tagion.services.options;
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
import tagion.behaviour.BehaviourException : check;
import tagion.tools.wallet.WalletInterface;
import tagion.hibon.HiBONRecord : isRecord;
import std.conv : to;
import std.stdio;
import std.format;
import std.algorithm;
import std.algorithm.comparison : equal;
import std.range;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;

void wrap_neuewelle(immutable(string)[] args) {
    neuewelle._main(cast(string[]) args);
}

mixin Main!(_main);
int _main(string[] args) {
    auto module_path = env.bdd_log.buildPath(__MODULE__);
    if (module_path.exists) {
        rmdirRecurse(module_path);
    }
    mkdirRecurse(module_path);
    string config_file = buildPath(module_path, "tagionwave.json");
    import std.exception : ifThrown;

    uint timeout = args[1].ifThrown("10").to!uint.ifThrown(10);
    long end_epoch = args[2].ifThrown("10000").to!long.ifThrown(10000);
    uint number_of_nodes = args[3].ifThrown("5").to!uint.ifThrown(5);

    scope Options local_options = Options.defaultOptions;
    local_options.dart.folder_path = buildPath(module_path);
    local_options.trt.folder_path = buildPath(module_path);
    local_options.replicator.folder_path = buildPath(module_path, "recorders");
    local_options.epoch_creator.timeout = timeout;
    local_options.wave.prefix_format = "EPOCH_TEST_Node_%s_";
    local_options.subscription.address = contract_sock_addr("EPOCH_OPERATIONAL_TEST_SUB");
    local_options.wave.number_of_nodes = number_of_nodes;
    local_options.save(config_file);

    import std.array;
    import tagion.crypto.SecureInterfaceNet;
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

    SecureNet net = createSecureNet;
    net.generateKeyPair("very_secret");

    auto factory = RecordFactory(net.hash);
    auto recorder = factory.recorder;
    recorder.insert(bills, Archive.Type.ADD);

    import tagion.tools.boot.genesis;
    import tagion.script.common;
    import tagion.hibon.Document;
    import tagion.hibon.BigNumber;
    import tagion.wave.mode0;

    const node_opts = getMode0Options(local_options);

    NodeSettings[] node_settings;
    auto nodenets = dummy_nodenets_for_testing(node_opts);
    foreach (opt, node_net; zip(node_opts, nodenets)) {
        node_settings ~= NodeSettings(
                opt.task_names.epoch_creator, // Name
                node_net.pubkey,
                opt.task_names.epoch_creator, // Address

                

        );
    }

    const genesis = createGenesis(
            node_settings,
            Document(),
            TagionGlobals(BigNumber(bills.map!(a => a.value.units).sum), BigNumber(0), bills.length, 0)
    );

    recorder.insert(genesis, Archive.Type.ADD);

    import tagion.trt.TRT;

    auto trt_recorder = factory.recorder;
    genesisTRT(bills, trt_recorder, net.hash);

    foreach (i; 0 .. local_options.wave.number_of_nodes) {
        immutable prefix = format(local_options.wave.prefix_format, i);
        const path = buildPath(local_options.dart.folder_path, prefix ~ local_options
                .dart.dart_filename);
        const trt_path = buildPath(local_options.trt.folder_path, prefix ~ local_options
                .trt.trt_filename);
        // writeln(path);
        // writeln(trt_path);
        DARTFile.create(path, net.hash);
        DARTFile.create(trt_path, net.hash);
        auto db = new DART(net.hash, path);
        auto trt_db = new DART(net.hash, trt_path);
        db.modify(recorder);
        trt_db.modify(trt_recorder);

        writefln("%s TRT bullseye: %(%02x%)", trt_path, trt_db.bullseye);
        writefln("%s DART bullseye: %(%02x%)", path, db.bullseye);

        db.close;
        trt_db.close;
    }
    immutable neuewelle_args = [
        "run_epochs_test", config_file
    ]; // ~ args;
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);
    auto name = "epoch_testing";
    Thread.sleep(1.seconds);
    register(name, thisTid);
    log.registerSubscriptionTask(name);

    auto feature = automation!(run_epochs);
    feature.RunPassiveFastNetwork(local_options.wave.number_of_nodes, end_epoch);
    feature.run;
    Thread.sleep(5.seconds);
    stopsignal.setIfInitialized;
    return 0;
}

enum feature = Feature(
            "Check network stability when runninng many epochs",
            []);

alias FeatureContext = Tuple!(
        RunPassiveFastNetwork, "RunPassiveFastNetwork",
        FeatureGroup*, "result"
);

@safe @Scenario("Run passive fast network",
        [])
class RunPassiveFastNetwork {
    import tagion.hashgraph.Refinement;
    import tagion.testbench.actor.util : receiveOnlyTimeout;
    import tagion.logger.LogRecords : LogInfo;

    enum EPOCH_TIMEOUT_SECONDS = 60;
    uint number_of_nodes;
    long last_epoch;
    long end_epoch;
    this(uint number_of_nodes, long end_epoch) {
        this.number_of_nodes = number_of_nodes;
        this.end_epoch = end_epoch;
    }

    @Given("i have a running network")
    Document network() {
        return result_ok;
    }

    @When("the nodes creates epochs")
    Document epochs() {
        submask.subscribe(StdRefinement.raw_epoch_events);
        long newest_epoch;

        // epoch <- taskname <- epoch_number
        FinishedEpoch[string][long] epochs;

        import tagion.testbench.hashgraph.hashgraph_test_network;

        while (newest_epoch < end_epoch) {
            auto finished_epoch_log = receiveOnlyTimeout!(LogInfo, const(Document))(EPOCH_TIMEOUT_SECONDS.seconds);
            check(finished_epoch_log[1].isRecord!(FinishedEpoch), "Did not receive finished epoch");
            FinishedEpoch epoch_received = FinishedEpoch(finished_epoch_log[1]);
            epochs[epoch_received.epoch][finished_epoch_log[0].to!string] = epoch_received;
            checkepoch(this.number_of_nodes, epochs, last_epoch);

            if (newest_epoch < epoch_received.epoch) {
                newest_epoch = epoch_received.epoch;
            }
        }
        return result_ok;
    }

    @Then("the epochs should be the same")
    Document same() {
        return result_ok;
    }

}
