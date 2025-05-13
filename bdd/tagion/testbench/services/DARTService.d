module tagion.testbench.services.DARTService;

import core.time;
import std.algorithm;
import std.array;
import std.file : exists, remove;
import std.path;
import std.stdio;
import std.typecons : Tuple;
import tagion.actor;
import tagion.behaviour;
import tagion.dart.DARTBasic : DARTIndex, Params;
import tagion.dart.Recorder;
import tagion.hibon.Document;
import tagion.services.DART;
import tagion.services.messages;
import tagion.testbench.dart.dart_helper_functions;
import tagion.testbench.tools.Environment;
import tagion.utils.pretend_safe_concurrency : receiveOnly, receiveTimeout, register, thisTid;

// import tagion.crypto.SecureNet;
import std.random;
import tagion.Keywords;
import tagion.basic.Types;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.DART;
import tagion.dart.DARTBasic;
import tagion.dart.DARTFile : DARTFile;
import tagion.dart.DARTcrud : dartBullseye, dartCheckRead, dartRead;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.logger.LogRecords : LogInfo;
import tagion.logger.Logger;
import tagion.services.rpcserver;
import tagion.services.TRTService;
import tagion.services.replicator;
import tagion.services.replicator : modify_log;
import tagion.testbench.actor.util;
import std.format;

enum feature = Feature(
            "see if we can read and write trough the dartservice",
            []);

alias FeatureContext = Tuple!(
        WriteAndReadFromDartDb, "WriteAndReadFromDartDb",
        FeatureGroup*, "result"
);

@safe
struct DARTWorker {
    void task(string sock_addr, Document doc, bool shouldError) @trusted {
        import nngd;

        int rc;
        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        s.recvtimeout = 1000.msecs;

        setState(Ctrl.ALIVE);
        while (!thisActor.stop) {
            const received = receiveTimeout(
                    Duration.zero,
                    &signal,
                    &ownerTerminated,
                    &unknown
            );

            writefln("REQ %s to dial...", doc.toPretty);
            rc = s.dial(sock_addr);
            if (rc == 0)
                break;
            writefln("REQ dial error %s", rc);
            if (rc == nng_errno.NNG_ECONNREFUSED) {
                nng_sleep(100.msecs);
            }
            check(rc == 0, "NNG error");
        }
        while (!thisActor.stop) {
            const received = receiveTimeout(
                    Duration.zero,
                    &signal,
                    &ownerTerminated,
                    &unknown
            );
            if (received) {
                continue;
            }
            rc = s.send!(immutable(ubyte[]))(doc.serialize);
            check(rc == 0, "NNG error");
            writefln("sent req");
            Document received_doc = s.receive!(immutable(ubyte[]))();
            thisActor.stop = true;
            check(s.errno == 0, format("Received not valid response from nng", s.errno));

            HiRPC hirpc = HiRPC(null);
            auto received_hirpc = hirpc.receive(received_doc);
            if (!shouldError) {
                check(!received_hirpc.isError, format("received hirpc error: %s", received_doc.toPretty));
            }
            else {
                check(received_hirpc.isError, format("Should have thrown error got: %s", received_doc.toPretty));
            }

        }
    }
}

@safe @Scenario("write and read from dart db",
        [])
class WriteAndReadFromDartDb {

    ActorHandle handle;
    ActorHandle rpcserver_handle;
    RPCServerOptions interface_opts;
    TRTOptions trt_options;

    SecureNet supervisor_net;
    DARTOptions opts;
    Mt19937 gen;
    RandomArchives random_archives;
    Document[] docs;
    RecordFactory.Recorder insert_recorder;
    RecordFactory record_factory;
    HiRPC hirpc;

    struct SimpleDoc {
        ulong n;
        mixin HiBONRecord!(q{
            this(ulong n) {
                this.n = n;
            }
        });
    }

    this(DARTOptions opts, TRTOptions trt_options) {

        this.opts = opts;
        this.trt_options = trt_options;
        supervisor_net = createSecureNet;
        supervisor_net.generateKeyPair("supervisor very secret");

        record_factory = RecordFactory(supervisor_net.hash);
        hirpc = HiRPC(supervisor_net);

        gen = Mt19937(1234);

    }

    @Given("I have a dart db")
    Document dartDb() {
        if (opts.dart_path.exists) {
            opts.dart_path.remove;
        }

        auto hash_net = new StdHashNet;
        DART.create(opts.dart_path, hash_net);
        return result_ok;
    }

    @Given("I have an dart actor with said db")
    Document saidDb() {
        thisActor.task_name = "dart_supervisor";
        register(thisActor.task_name, thisTid);

        import tagion.services.options : TaskNames;

        writeln("DART task name", TaskNames().dart);

        auto net = createSecureNet;
        net.generateKeyPair("dartnet very secret");

        handle = (() @trusted => spawn!DARTService(TaskNames().dart, cast(immutable) opts, cast(shared) net))();

        interface_opts.setDefault;
        writeln(interface_opts.sock_addr);

        rpcserver_handle = (() @trusted => spawn(immutable(RPCServer)(cast(immutable) interface_opts, cast(immutable) trt_options, TaskNames()), "DartInterfaceService"))();

        waitforChildren(Ctrl.ALIVE, 3.seconds);

        return result_ok;
    }

    @When("I send a dartModify command with a recorder containing changes to add")
    Document toAdd() {
        log.registerSubscriptionTask(thisActor.task_name);
        submask.subscribe(DARTService.recorder_created);

        foreach (i; 0 .. 100) {
            gen.popFront;
            random_archives = RandomArchives(gen.front, 4, 10);
            insert_recorder = record_factory.recorder;
            docs = (() @trusted => cast(Document[]) random_archives.values.map!(a => SimpleDoc(a).toDoc).array)();

            insert_recorder.insert(docs, Archive.Type.ADD);
            (() @trusted => handle.send(dartModifyRR(), cast(immutable) insert_recorder))();

            auto new_bullseye = receiveOnlyTimeout!(dartModifyRR.Response, Fingerprint);

            auto modify_log_result = receiveOnlyTimeout!(LogInfo, const(Document));
            check(modify_log_result[1].isRecord!(RecordFactory.Recorder), "Did not receive recorder");

            handle.send(dartBullseyeRR());
            const bullseye_res = receiveOnly!(dartBullseyeRR.Response, Fingerprint);
            check(bullseye_res[1]!is Fingerprint.init, "bullseyes not the same");

            Document bullseye_sender = dartBullseye(hirpc).toDoc;

            handle.send(dartHiRPCRR(), bullseye_sender);
            // writefln("SENDER: %s", bullseye_sender.toPretty);
            auto hirpc_bullseye_res = receiveOnly!(dartHiRPCRR.Response, Document);
            // writefln("RECEIVER %s", hirpc_bullseye_res[1].toPretty);

            auto hirpc_bullseye_receiver = hirpc.receive(hirpc_bullseye_res[1]);
            auto hirpc_message = hirpc_bullseye_receiver.message[Keywords.result].get!Document;
            auto hirpc_bullseye = hirpc_message[Params.bullseye].get!DARTIndex;
            check(bullseye_res[1] == hirpc_bullseye, "hirpc bullseye not the same");

            /// read the archives
            auto dart_indices = docs
                .map!(d => supervisor_net.hash.dartIndex(d))
                .array;

            auto read_request = dartReadRR();
            handle.send(read_request, dart_indices);
            auto read_tuple = receiveOnly!(dartReadRR.Response, immutable(RecordFactory.Recorder));
            auto read_recorder = read_tuple[1];

            check(equal(read_recorder[].map!(a => a.filed), insert_recorder[].map!(a => a.filed)), "Data not the same");

            Document read_sender = dartRead(dart_indices, hirpc).toDoc;

            handle.send(dartHiRPCRR(), read_sender);

            auto read_hirpc = receiveOnly!(dartHiRPCRR.Response, Document);
            auto read_hirpc_recorder = hirpc.receive(read_hirpc[1]);
            auto hirpc_recorder_message = read_hirpc_recorder.message[Keywords.result].get!Document;

            const hirpc_recorder = record_factory.recorder(hirpc_recorder_message);

            check(equal(hirpc_recorder[].map!(a => a.filed), insert_recorder[].map!(a => a.filed)), "hirpc data not the same as insertion");

            Document check_read_sender = dartCheckRead(dart_indices, hirpc).toDoc;
            handle.send(dartHiRPCRR(), check_read_sender);
            auto read_check_tuple = receiveOnly!(dartHiRPCRR.Response, Document);
            auto read_check = hirpc.receive(read_check_tuple[1]);

            auto check_dart_indices = read_check.response.result[Params.dart_indices].get!Document[].map!(
                    d => d.get!DARTIndex).array;

            check(check_dart_indices.length == 0, "should be empty");

        }
        submask.unsubscribe(modify_log);

        auto dummy_indices = [DARTIndex([1, 2, 3, 4]), DARTIndex([2, 3, 4, 5])];
        Document check_read_sender = dartCheckRead(dummy_indices, hirpc).toDoc;
        writefln("read_sender %s", check_read_sender.toPretty);
        handle.send(dartHiRPCRR(), check_read_sender);
        auto read_check_tuple = receiveOnly!(dartHiRPCRR.Response, Document);
        auto read_check = hirpc.receive(read_check_tuple[1]);

        auto check_dart_indices = read_check.response.result[Params.dart_indices].get!Document[].map!(d => d.get!DARTIndex)
            .array;

        check(equal(check_dart_indices, dummy_indices), "error in hirpc checkread");

        auto t1 = spawn!DARTWorker("dartworker1", interface_opts.sock_addr, check_read_sender, false);
        auto t2 = spawn!DARTWorker("dartworker2", interface_opts.sock_addr, check_read_sender, false);
        auto t3 = spawn!DARTWorker("dartworker3", interface_opts.sock_addr, check_read_sender, false);

        // send a message that should fail
        auto t4 = spawn!DARTWorker("dartworker4", interface_opts.sock_addr, read_check_tuple[1], true);

        import core.thread;

        (() @trusted => Thread.sleep(3000.msecs))();

        return result_ok;
    }

    @When("I send a dartRead command to see if it has the changed")
    Document theChanged() @trusted {
        // checked above

        return result_ok;
    }

    @Then("the read recorder should be the same as the dartModify recorder")
    Document dartModifyRecorder() {
        // checked above

        handle.send(Sig.STOP);
        waitforChildren(Ctrl.END);

        return result_ok;
    }

}
