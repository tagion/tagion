module tagion.testbench.services.DARTService;

import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.actor;
import tagion.services.DART;
import tagion.services.messages;
import std.stdio;
import std.path;
import std.file : exists, remove;
import std.algorithm;
import std.array;
import tagion.testbench.dart.dart_helper_functions;
import tagion.dart.Recorder;
import tagion.utils.pretend_safe_concurrency : receiveTimeout, receiveOnly, register, thisTid;
import tagion.dart.DARTBasic : DARTIndex;
import core.time;

// import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdHashNet, StdSecureNet;
import tagion.dart.DART;
import tagion.dart.DARTBasic;
import std.random;
import tagion.hibon.HiBONRecord;
import tagion.basic.Types;
import tagion.crypto.Types;
import tagion.communication.HiRPC;
import tagion.dart.DARTcrud : dartRead, dartBullseye, dartCheckRead;
import tagion.dart.DARTFile : DARTFile;
import tagion.hibon.HiBONJSON;
import tagion.Keywords;
import tagion.services.replicator;
import tagion.services.DARTInterface;
import tagion.services.replicator : modify_log;
import tagion.logger.Logger;
import tagion.logger.LogRecords : LogInfo;
import tagion.testbench.actor.util;

enum feature = Feature(
            "see if we can read and write trough the dartservice",
            []);

alias FeatureContext = Tuple!(
        WriteAndReadFromDartDb, "WriteAndReadFromDartDb",
        FeatureGroup*, "result"
);

@safe
struct DARTWorker {
    void task(string sock_addr, Document doc) @trusted {
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
            if (s.errno == 0) {
                writefln("RECEIVED RESPONSE: %s", received_doc.toPretty);
                thisActor.stop = true;
            }
            else {
                writefln("ERROR %s", s.errno);
                thisActor.stop = true;
            }
        }
    }
}

@safe @Scenario("write and read from dart db",
        [])
class WriteAndReadFromDartDb {

    DARTServiceHandle handle;
    DARTInterfaceServiceHandle dart_interface_handle;
    ReplicatorServiceHandle replicator_handle;  
    DARTInterfaceOptions interface_opts;

    SecureNet supervisor_net;
    DARTOptions opts;
    ReplicatorOptions replicator_opts;
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

    this(DARTOptions opts, ReplicatorOptions replicator_opts) {

        this.opts = opts;
        this.replicator_opts = replicator_opts;
        supervisor_net = new StdSecureNet();
        supervisor_net.generateKeyPair("supervisor very secret");

        record_factory = RecordFactory(supervisor_net);
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

        auto net = new StdSecureNet();
        net.generateKeyPair("dartnet very secret");

        
        handle = (() @trusted => spawn!DARTService(TaskNames().dart, cast(immutable) opts, TaskNames(), cast(
                shared) net))();

        
        replicator_handle =(() @trusted => spawn!ReplicatorService(
            TaskNames().replicator, 
            cast(immutable) replicator_opts))();

        interface_opts.setDefault;
        writeln(interface_opts.sock_addr);

        dart_interface_handle = (() @trusted => spawn(immutable(DARTInterfaceService)(cast(immutable) interface_opts, TaskNames()), "DartInterfaceService"))();


        waitforChildren(Ctrl.ALIVE, 3.seconds);

        return result_ok;
    }

    @When("I send a dartModify command with a recorder containing changes to add")
    Document toAdd() {
        log.registerSubscriptionTask(thisActor.task_name);
        submask.subscribe(modify_log);
        
        foreach (i; 0 .. 100) {
            gen.popFront;
            random_archives = RandomArchives(gen.front, 4, 10);
            insert_recorder = record_factory.recorder;
            docs = (() @trusted => cast(Document[]) random_archives.values.map!(a => SimpleDoc(a).toDoc).array)();

            insert_recorder.insert(docs, Archive.Type.ADD);
            auto modify_send = dartModifyRR();
            (() @trusted => handle.send(modify_send, cast(immutable) insert_recorder, immutable long(i)))();

            auto modify = receiveOnlyTimeout!(dartModifyRR.Response, Fingerprint);


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
            auto hirpc_bullseye = hirpc_message[DARTFile.Params.bullseye].get!DARTIndex;
            check(bullseye_res[1] == hirpc_bullseye, "hirpc bullseye not the same");

            /// read the archives
            auto dart_indices = docs
                .map!(d => supervisor_net.dartIndex(d))
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

            auto check_dart_indices = read_check.response.result[DART.Params.dart_indices].get!Document[].map!(
                    d => d.get!DARTIndex).array;

            check(check_dart_indices.length == 0, "should be empty");

        }
        submask.unsubscribe(modify_log);

        auto dummy_indexes = [DARTIndex([1, 2, 3, 4]), DARTIndex([2, 3, 4, 5])];
        Document check_read_sender = dartCheckRead(dummy_indexes, hirpc).toDoc;
        writefln("read_sender %s", check_read_sender.toPretty);
        handle.send(dartHiRPCRR(), check_read_sender);
        auto read_check_tuple = receiveOnly!(dartHiRPCRR.Response, Document);
        auto read_check = hirpc.receive(read_check_tuple[1]);

        auto check_dart_indices = read_check.response.result[DART.Params.dart_indices].get!Document[].map!(d => d.get!DARTIndex)
            .array;

        check(equal(check_dart_indices, dummy_indexes), "error in hirpc checkread");

        auto t1 = spawn!DARTWorker("dartworker1", interface_opts.sock_addr, check_read_sender);
        auto t2 = spawn!DARTWorker("dartworker2", interface_opts.sock_addr, check_read_sender);
        auto t3 = spawn!DARTWorker("dartworker3", interface_opts.sock_addr, check_read_sender);

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
