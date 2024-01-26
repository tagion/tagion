module tagion.testbench.services.collector;
// Default import list for bdd
import core.time;
import std.algorithm.iteration : map;
import std.array;
import std.exception;
import std.file : exists, mkdirRecurse, remove, rmdirRecurse;
import std.format : format;
import std.path : buildPath, dirName, setExtension;
import std.range : iota, take, zip;
import std.typecons : Tuple;
import tagion.actor;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.DARTBasic;
import tagion.dart.Recorder;
import tagion.hibon.Document;
import tagion.logger.LogRecords : LogInfo;
import tagion.logger.Logger;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.execute;
import tagion.services.DART;
import tagion.services.collector;
import tagion.services.messages;
import tagion.services.options : TaskNames;
import tagion.services.replicator;
import tagion.testbench.actor.util;
import tagion.testbench.tools.Environment;
import tagion.utils.StdTime;
import tagion.utils.pretend_safe_concurrency : receive, receiveOnly, receiveTimeout;
import tagion.basic.Debug;
import tagion.hibon.HiBONJSON;

enum feature = Feature(
            "collector services",
            []);

alias FeatureContext = Tuple!(
        ItWork, "ItWork",
        FeatureGroup*, "result"
);

SecureNet[] createNets(uint count, string pass_prefix = "net") @safe {
    return iota(0, count).map!((i) {
        SecureNet net = new StdSecureNet();
        net.generateKeyPair(format("%s_%s", pass_prefix, i));
        return net;
    }).array;
}

TagionBill[] createBills(const(SecureNet)[] bill_nets, uint amount) @safe {
    return bill_nets.map!((net) =>
            TagionBill(TGN(amount), currentTime, net.pubkey, Buffer.init)
    ).array;
}

const(DARTIndex)[] insertBills(TagionBill[] bills, ref RecordFactory.Recorder rec) @safe {
    rec.insert(bills, Archive.Type.ADD);
    return rec[].map!((a) => a.dart_index).array;
}

TagionBill createBill(const TagionCurrency tgn) pure nothrow @safe{
    return TagionBill(tgn, sdt_t.init, Pubkey.init, Buffer.init);
}

@safe @Scenario("it work", [])
class ItWork {
    enum dart_service = "dart_service_task";
    ActorHandle dart_handle;
    ActorHandle collector_handle;
    ActorHandle replicator_handle;

    TagionBill[] input_bills;
    SecureNet[] input_nets;

    immutable SecureNet node_net;
    this() {
        SecureNet _net = new StdSecureNet();
        _net.generateKeyPair("very secret");
        node_net = (() @trusted => cast(immutable) _net)();
    }

    @Given("i have a collector service")
    Document service() @safe {
        thisActor.task_name = "collector_tester_task";
        log.registerSubscriptionTask(thisActor.task_name);
        submask.subscribe(reject_collector);

        immutable task_names = TaskNames();
        { // Start dart service
            auto module_path = env.bdd_log.buildPath(__MODULE__);
            immutable opts = DARTOptions(
                    module_path,
                    "dart".setExtension(FileExtension.dart),
            );

            auto replicator_path = buildPath(module_path, "replicator");
            immutable replicator_opts = ReplicatorOptions(replicator_path);

            mkdirRecurse(replicator_path);
            if (replicator_path.exists) {
                rmdirRecurse(replicator_path);
            }
            mkdirRecurse(opts.dart_filename.dirName);

            if (opts.dart_path.exists) {
                opts.dart_path.remove;
            }

            import tagion.dart.DART;

            DART.create(opts.dart_path, node_net);

            auto dart_net = new StdSecureNet;
            dart_net.generateKeyPair("dartnet");
            dart_handle = (() @trusted => spawn!DARTService(task_names.dart, opts, task_names, cast(shared) dart_net, false))();
            replicator_handle = (() @trusted => spawn!ReplicatorService(task_names.replicator, replicator_opts))();
            check(waitforChildren(Ctrl.ALIVE), "dart service did not alive");
        }

        auto record_factory = RecordFactory(node_net);
        auto insert_recorder = record_factory.recorder;

        input_nets = createNets(10, "input");
        input_bills = input_nets.createBills(100_000);
        input_bills.insertBills(insert_recorder);
        __write("insert_recorder=%s", insert_recorder.toPretty);
        dart_handle.send(dartModifyRR(), RecordFactory.uniqueRecorder(insert_recorder), immutable long(0));
        receiveOnlyTimeout!(dartModifyRR.Response, Fingerprint);

        {
            import tagion.utils.pretend_safe_concurrency;

            register(task_names.tvm, thisTid);
        }
        collector_handle = _spawn!CollectorService(task_names.collector, task_names);
        check(waitforChildren(Ctrl.ALIVE), "CollectorService never alived");
        return result_ok;
    }

    @When("i send a contract")
    Document contract() {
        __write("test %s", __FUNCTION__);
        const script = PayScript(iota(1, 11).map!(i => createBill(i.TGN)).array).toDoc;
        const s_contract = sign(input_nets, input_bills.map!(a => a.toDoc).array, null, script);

        __write("%s s_contract =%s", __FUNCTION__, s_contract.toPretty);
        import std.stdio;
        import tagion.hibon.HiBONJSON;

        writeln(s_contract.toPretty);

        const hirpc = HiRPC(node_net);
        immutable sender = hirpc.sendDaMonies(s_contract);
        collector_handle.send(inputHiRPC(), hirpc.receive(sender.toDoc));

        auto collected = receiveOnlyTimeout!(signedContract, immutable(CollectedSignedContract)*)[1];

        check(collected !is null, "The collected was null");
        // check(collected.inputs.length == inputs.length, "The lenght of inputs were not the same");
        // check(collected.inputs.map!(a => node_net.dartIndex(a)).array == inputs, "The collected archives did not match the index");
        return result_ok;
    }

    @When("i send an contract with no inputs")
    Document noInputs() {
        __write("test %s", __FUNCTION__);
        const outputs = PayScript.init.toDoc; //(iota(1, 11).map!(i => createBill(i.TGN)).array).toDoc;
        const contract = Contract(DARTIndex[].init, DARTIndex[].init, outputs);
        const s_contract = SignedContract(Signature[].init, contract);

        const hirpc = HiRPC(node_net);
        immutable sender = hirpc.sendDaMonies(s_contract);
        __write("send %s %s", __FUNCTION__, sender.toPretty);    
    //immutable sender = hirpc.sendDaMonies(contract);
        collector_handle.send(inputHiRPC(), hirpc.receive(sender.toDoc));

        auto result = receiveOnlyTimeout!(LogInfo, const(Document));
        __write("%s result=%s", __FUNCTION__, result[0].symbol_name); 
        check(result[0].symbol_name == "hirpc_invalid_signed_contract", "did not reject for the expected reason, got %s"
                .format(result[0].symbol_name));

        return result_ok;
    }

    @When("i send an contract with invalid signatures inputs")
    Document invalidSignatures() {
        __write("test %s", __FUNCTION__);
        import std.random;

        const script = PayScript(iota(1, 11).map!(i => createBill(i.TGN)).array).toDoc;
        const s_contract = sign(input_nets.randomShuffle, input_bills.map!(a => a.toDoc).array, null, script);

        const hirpc = HiRPC(node_net);
        immutable sender = hirpc.sendDaMonies(s_contract);
        collector_handle.send(inputHiRPC(), hirpc.receive(sender.toDoc));

        auto result = receiveOnlyTimeout!(LogInfo, const(Document));
        check(result[0].symbol_name == "contract_no_verify", "did not reject for the expected reason got, %s".format(result[0]
                .symbol_name));

        return result_ok;
    }

    @When("i send a contract with input which are not in the dart")
    Document inTheDart() {
        __write("test %s", __FUNCTION__);
        const script = PayScript(iota(1, 11).map!(i => createBill(i.TGN)).array).toDoc;

        const invalid_inputs = createNets(10, "not_int_dart")
            .createBills(100_000)
            .map!(a => a.toDoc)
            .array;

        const s_contract = sign(input_nets, invalid_inputs, null, script);

        const hirpc = HiRPC(node_net);
        immutable sender = hirpc.sendDaMonies(s_contract);
        collector_handle.send(inputHiRPC(), hirpc.receive(sender.toDoc));

        auto result = receiveOnlyTimeout!(LogInfo, const(Document));
        check(result[0].symbol_name == "missing_archives", "did not reject for the expected reason");

        return result_ok;
    }

    @Then("i stop the services")
    Document collectedSignedContract() {
        __write("test %s", __FUNCTION__);
        dart_handle.send(Sig.STOP);
        collector_handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);

        return result_ok;
    }
}
