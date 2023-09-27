/// Tagion DART actor service
module tagion.services.DART;

import std.path : isValidPath;
import std.format : format;
import std.file;
import std.algorithm : map;
import std.array;
import std.stdio;
import std.path;
import std.exception;

import tagion.utils.pretend_safe_concurrency;
import tagion.utils.JSONCommon;
import tagion.basic.Types : FileExtension;
import tagion.actor;
import tagion.crypto.Types;
import tagion.crypto.SecureInterfaceNet;
import tagion.dart.DART;
import tagion.dart.Recorder;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.hibon.Document;
import tagion.services.messages;
import tagion.communication.HiRPC;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.logger.Logger;
import tagion.services.replicator;
import tagion.services.options : TaskNames;

@safe
struct DARTOptions {
    string folder_path = buildPath(".");
    string dart_filename = "dart".setExtension(FileExtension.dart);
    string dart_path;

    this(string folder_path, string dart_filename) {
        this.folder_path = folder_path;
        this.dart_filename = dart_filename;
        dart_path = buildPath(folder_path, dart_filename);
    }

    void setPrefix(string prefix) nothrow {
        dart_filename = prefix ~ dart_filename;
        dart_path = buildPath(folder_path, dart_filename);
    }

    mixin JSONCommon;
}

@safe
struct DARTService {
    void task(immutable(DARTOptions) opts, immutable(ReplicatorOptions) replicator_opts, immutable(TaskNames) task_names, immutable(
            SecureNet) net) {
        DART db;
        Exception dart_exception;
        immutable replicator_task_name = task_names.replicator;
        db = new DART(net, opts.dart_path);
        if (dart_exception !is null) {
            throw dart_exception;
        }

        scope (exit) {
            db.close();
        }

        ReplicatorServiceHandle replicator = spawn!ReplicatorService(replicator_task_name, replicator_opts, net);

        waitforChildren(Ctrl.ALIVE);

        void read(dartReadRR req, immutable(DARTIndex)[] fingerprints) @safe {
            RecordFactory.Recorder read_recorder = db.loads(fingerprints);
            req.respond(RecordFactory.uniqueRecorder(read_recorder));
        }

        void checkRead(dartCheckReadRR req, immutable(DARTIndex)[] fingerprints) @safe {
            auto check_read = db.checkload(fingerprints);
            (() @trusted => req.respond(cast(immutable) check_read))();
        }

        auto hirpc = HiRPC(net);
        auto empty_hirpc = HiRPC(null);
        import tagion.Keywords;

        void dartHiRPC(dartHiRPCRR req, Document doc) {
            log("Received HiRPC request");

            if (!doc.isRecord!(HiRPC.Sender)) {
                import tagion.hibon.HiBONJSON;

                assert(0, format("wrong request sent to dartservice. Expected HiRPC.Sender got %s", doc.toPretty));
            }

            immutable receiver = empty_hirpc.receive(doc);

            assert(receiver.method.name == DART.Queries.dartRead || receiver.method.name == DART.Queries.dartBullseye || receiver
                    .method.name == DART.Queries.dartCheckRead, "unsupported hirpc request");

            Document result = db(receiver, false).toDoc;
            req.respond(result);
        }

        void modify(dartModify, immutable(RecordFactory.Recorder) recorder, immutable(int) epoch_number) @safe {
            auto eye = Fingerprint(db.modify(recorder));

            locate(replicator_task_name).send(SendRecorder(), recorder, eye, epoch_number);
        }

        void bullseye(dartBullseyeRR req) @safe {
            auto eye = Fingerprint(db.bullseye);
            req.respond(eye);
        }

        run(&read, &checkRead, &modify, &bullseye, &dartHiRPC);

    }
}

alias DARTServiceHandle = ActorHandle!DARTService;
