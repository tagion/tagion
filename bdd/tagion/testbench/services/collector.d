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

debug {
    import std.stdio;
    import tagion.hibon.HiBONJSON;
    import tagion.hibon.HiBONtoText;
}

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

TagionBill[] createBills(StdSecureNet[] bill_nets, uint amount) @trusted {
    import core.thread;
    import core.time;

    Thread.sleep(10.msecs);
    return bill_nets.map!((net) =>
            TagionBill(TGN(amount), currentTime, net.pubkey)
    ).array;
}

const(DARTIndex)[] insertBills(TagionBill[] bills, ref RecordFactory.Recorder rec) @safe {
    rec.insert(bills, Archive.Type.ADD);
    return rec[].map!((a) => a.fingerprint).array;
}

@safe @Scenario("it work", [])
class ItWork {
    enum dart_service = "dart_service_task";
    DARTServiceHandle dart_handle;
    CollectorServiceHandle collector_handle;

    immutable(DARTIndex)[] inputs;
    TagionBill[] input_bills;
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
            mkdirRecurse(opts.dart_filename.dirName);
            if (opts.dart_filename.exists) {
                opts.dart_filename.remove;
            }

            import tagion.dart.DART;

            DART.create(opts.dart_filename, node_net);

            dart_handle = spawn!DARTService(dart_service, opts, node_net);
            check(waitforChildren(Ctrl.ALIVE), "dart service did not alive");
        }

        auto record_factory = RecordFactory(node_net);
        auto insert_recorder = record_factory.recorder;

        input_nets = createNets(10, "input");
        input_bills = input_nets.createBills(100_000);
        input_bills.insertBills(insert_recorder);
        inputs ~= input_bills.map!(a => node_net.dartIndex(a.toDoc)).array;
        check(inputs !is null, "Inputs were null");
        dart_handle.send(dartModifyRR(),
                (() @trusted => cast(immutable) insert_recorder)()
        );
        receiveOnlyTimeout!(dartModifyRR.Response, immutable(DARTIndex));

        immutable collector = CollectorService(node_net, dart_service, thisActor.task_name);
        collector_handle = spawn(collector, "collector_task");
        check(waitforChildren(Ctrl.ALIVE), "CollectorService never alived");

        //         return result_ok;
        //     }
        // 
        //     @When("i send a contract")
        //     Document contract() @trusted {
        import std.exception;

        immutable outputs = PayScript(iota(0, 10).map!(_ => TGN(100_000)).array).toDoc;
        immutable contract = immutable(Contract)(inputs, immutable(DARTIndex[]).init, outputs);
        check(Contract(contract.toDoc).inputs == contract.inputs, "Input bills and ordered inputs bills were not the same");
        import std.algorithm.sorting;

        immutable signs = {
            Signature[] _signs;
            const contract_hash = node_net.calcHash(contract.toDoc);
            foreach (net; input_nets) {
                _signs ~= net.sign(contract_hash);
            }
            return _signs.assumeUnique;
        }();
        check(signs !is null, "Signs is null");

        immutable s_contract = immutable(SignedContract)(signs, contract);

        writeln("Input order");
        const contract_hash = node_net.calcHash(contract.toDoc);
        foreach (index, sign; zip(s_contract.contract.inputs, s_contract.signs)) {
            const archive = find(insert_recorder, index);
            check(archive !is null, format("Archive %s, did not exist in recorder", index));

            immutable bill = TagionBill(archive.filed);
            writefln("f:%s", archive.fingerprint.encodeBase64);
            writefln("s:%s", sign.encodeBase64);
            writefln("p:%s", bill.owner.encodeBase64);

            // bool verify(const fingerprint message, const signature signature, const pubkey pubkey)
            if (!node_net.verify(contract_hash, sign, bill.owner)) {
                writeln("could not be verified");
                check(false, "could not be verified");
            }
        }

        import tagion.communication.HiRPC;

        const hirpc = HiRPC(node_net);
        immutable sender = hirpc.sendDaMonies(s_contract);
        collector_handle.send(inputHiRPC(), hirpc.receive(sender.toDoc));

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
