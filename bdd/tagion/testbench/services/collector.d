module tagion.testbench.services.collector;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import std.path : dirName, setExtension, buildPath;
import std.file : mkdirRecurse, exists, remove;
import std.range : iota, zip, take;
import std.algorithm.iteration : map;
import std.format : format;
import std.array;

import tagion.testbench.actor.util;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.crypto.SecureInterfaceNet;
import tagion.script.execute;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.actor;
import tagion.services.messages;
import tagion.services.collector;
import tagion.services.DART;
import tagion.utils.StdTime;
import tagion.basic.Types : FileExtension, Buffer;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic;
import tagion.services.replicator : ReplicatorOptions;

enum feature = Feature(
            "collector services",
            []);

alias FeatureContext = Tuple!(
        ItWork, "ItWork",
        FeatureGroup*, "result"
);

StdSecureNet[] createNets(uint count, string pass_prefix = "net") @safe {
    return iota(0, count).map!((i) {
        auto net = new StdSecureNet();
        net.generateKeyPair(format("%s_%s", pass_prefix, i));
        return net;
    }).array;
}

TagionBill[] createBills(StdSecureNet[] bill_nets, uint amount) @safe {
    return bill_nets.map!((net) =>
            TagionBill(TGN(amount), currentTime, net.pubkey, Buffer.init)
    ).array;
}

const(DARTIndex)[] insertBills(TagionBill[] bills, ref RecordFactory.Recorder rec) @safe {
    rec.insert(bills.map!(bill => bill.toDoc), Archive.Type.ADD);
    return rec[].map!((a) => a.fingerprint).array;
}

@safe @Scenario("it work", [])
class ItWork {
    enum dart_service = "dart_service_task";
    DARTServiceHandle dart_handle;
    CollectorServiceHandle collector_handle;

    immutable(DARTIndex)[] inputs;
    StdSecureNet[] input_nets;

    immutable SecureNet node_net;
    this() {
        SecureNet _net = new StdSecureNet();
        _net.generateKeyPair("very secret");
        node_net = (() @trusted => cast(immutable) _net)();
    }

    @Given("i have a collector service")
    Document service() @trusted {
        thisActor.task_name = "collector_tester_task";

        { // Start dart service
            immutable opts = DARTOptions(
                    buildPath(env.bdd_results, __MODULE__, "dart".setExtension(FileExtension.dart))
            );
            immutable replicator_folder = buildPath(opts.dart_filename.dirName, "replicator");
            immutable replicator_opts = ReplicatorOptions(replicator_folder);

            mkdirRecurse(replicator_folder);
            mkdirRecurse(opts.dart_filename.dirName);

            if (opts.dart_filename.exists) {
                opts.dart_filename.remove;
            }

            import tagion.dart.DART;

            DART.create(opts.dart_filename, node_net);

            dart_handle = spawn!DARTService(dart_service, opts, replicator_opts, "replicator",node_net);
            check(waitforChildren(Ctrl.ALIVE), "dart service did not alive");
        }

        auto record_factory = RecordFactory(node_net);
        auto insert_recorder = record_factory.recorder;
        auto output_recorder = record_factory.recorder;

        input_nets = createNets(10, "input");
        inputs ~= input_nets.createBills(100_000).insertBills(insert_recorder);
        dart_handle.send(dartModify(),
                (() @trusted => cast(immutable) insert_recorder)(), immutable int(0)
        );
        import core.time;
        import core.thread;
        (() @trusted => Thread.sleep(5.msecs))();

        // dart_handle.send(dartBullseyeRR());
        immutable collector = CollectorService(node_net, dart_service, thisActor.task_name);
        collector_handle = spawn(collector, "collector_task");
        check(waitforChildren(Ctrl.ALIVE), "CollectorService never alived");

        return result_ok;
    }

    @When("i send a contract")
    Document contract() @trusted {
        import std.exception;

        immutable outputs = PayScript(iota(0, 10).map!(_ => TagionBill.init).array).toDoc;
        immutable contract = cast(immutable) Contract(inputs, immutable(DARTIndex[]).init, outputs);
        immutable signs = {
            immutable(Signature)[] signs;
            foreach (fprint; inputs) {
                signs ~= node_net.sign(node_net.calcHash(cast(Buffer) fprint));
            }
            return signs;
        };

        // check(node_net.verify(insert_recorder[].take(1).dartFingerprint, signs()[0], node_net.pubkey));
        immutable s_contract = cast(immutable) SignedContract(signs(), cast(immutable) contract);
        collector_handle.send(inputContract(), s_contract);
        return result_ok;
    }

    @Then("i receive a `CollectedSignedContract`")
    Document collectedSignedContract() {
        receiveOnlyTimeout!(signedContract, immutable(CollectedSignedContract)*);
        dart_handle.send(Sig.STOP);
        collector_handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);

        return result_ok;
    }

}
