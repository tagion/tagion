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
    uint timeout = args[1].to!uint.ifThrown(10);

    scope Options local_options = Options.defaultOptions;
    local_options.dart.folder_path = buildPath(module_path);
    local_options.trt.folder_path = buildPath(module_path);
    local_options.replicator.folder_path = buildPath(module_path, "recorders");
    local_options.epoch_creator.timeout = timeout;
    local_options.wave.prefix_format = "EPOCH_TEST_Node_%s_";
    local_options.subscription.address = contract_sock_addr("EPOCH_OPERATIONAL_TEST_SUB");
    local_options.save(config_file);

    import std.algorithm;
    import std.array;
    import std.range;
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

    import tagion.tools.boot.genesis;
    import tagion.script.common;
    import tagion.hibon.Document;
    import tagion.hibon.BigNumber;
    import tagion.wave.mode0;

    const node_opts = getMode0Options(local_options, monitor: false);

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
        "run_epochs_test", config_file
    ]; // ~ args;
    auto tid = spawn(&wrap_neuewelle, neuewelle_args);
    auto name = "epoch_testing";
    Thread.sleep(1.seconds);
    register(name, thisTid);
    log.registerSubscriptionTask(name);

    auto feature = automation!(run_epochs);
    feature.RunPassiveFastNetwork(local_options.wave.number_of_nodes, args[2].to!long);
    feature.run;
    Thread.sleep(5.seconds);
    stopsignal.set;
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

    uint number_of_nodes;
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
        submask.subscribe(StdRefinement.epoch_created);
        long newest_epoch;


        // epoch <- taskname <- epoch_number
        FinishedEpoch[string][long] epochs;

        void checkepochs() {
            writefln("unfinished epochs %s", epochs.length);
            foreach(epoch; epochs.byKeyValue) {
                if (epoch.value.length == this.number_of_nodes) {
                    writeln("FINISHED ENTIRE EPOCH");
                    epochs.remove(epoch.key);
                }
            }

        }
        
        while(newest_epoch < end_epoch) {
            auto finished_epoch_log = receiveOnlyTimeout!(LogInfo, const(Document))(10.seconds);
            check(finished_epoch_log[1].isRecord!(FinishedEpoch), "Did not receive finished epoch");
            FinishedEpoch epoch_received = FinishedEpoch(finished_epoch_log[1]);
            epochs[epoch_received.epoch][finished_epoch_log[0].to!string] = epoch_received;
            checkepochs;
            newest_epoch++;
        }
        return result_ok;
    }

    @Then("the epochs should be the same")
    Document same() {
        return result_ok;
    }

}
