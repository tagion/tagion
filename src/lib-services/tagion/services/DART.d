/// Tagion DART actor service
module tagion.services.DART;

import std.algorithm : map, filter, canFind;
import std.array;
import std.exception;
import std.file;
import std.format : format;
import std.path : isValidPath;
import std.path;
import std.stdio;
import tagion.actor;
import tagion.basic.Types;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.DART;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.dart.DARTException;
import tagion.dart.Recorder;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.logger.Logger;
import tagion.services.messages;
import tagion.services.options : TaskNames;
import tagion.services.replicator;
import tagion.utils.JSONCommon;
import tagion.utils.pretend_safe_concurrency;
import tagion.services.exception;
import tagion.services.DARTInterface : accepted_dart_methods;

@safe:
///
struct DARTOptions {
    string folder_path = buildPath(".");
    string dart_filename = "dart".setExtension(FileExtension.dart);

    string dart_path() inout nothrow {
        return buildPath(folder_path, dart_filename);
    }

    void setPrefix(string prefix) nothrow {
        dart_filename = prefix ~ dart_filename;
    }

    mixin JSONCommon;
}

/** 
 * DART Service actor
 * Responsible for interfacing with the DART. Handling reads and writes.
 * Main function is the modify, which receives the updates to add from the TaskNames.Transcript actor.
 * Sends: 
 * (SendRecorder(), immutable(RecordFactory.Recorder, immutable(DARTIndex), immutable(long)) to TaskNames.Replicator 
 * HiRPC Request-Respond requests:
 * (dartHiRPCRR,doc) -> HiRPC.Result ( dartRim, dartBullseye, dartCheckRead, dartRim ))
 * (dartCheckReadRR, immutable(DARTIndex)[]) -> (immutable(DARTIndex)[])
 * (dartBullseyeRR) -> (Fingerprint)
 * (dartReadRR, immutable(DARTIndex)[]) -> (immutable(RecordFactory.Recorder))
 */
struct DARTService {
    static Topic recorder_created = Topic("recorder");

    void task(immutable(DARTOptions) opts,
            immutable(TaskNames) task_names,
            shared(StdSecureNet) shared_net,
            bool trt_enable) {

        DART db;
        Exception dart_exception;
        const net = new StdSecureNet(shared_net);
        check(opts.dart_path.exists, format("DART database %s file not found", opts.dart_path));
        db = new DART(net, opts.dart_path);
        if (dart_exception !is null) {
            throw dart_exception;
        }

        ActorHandle replicator_handle = ActorHandle(task_names.replicator);
        ActorHandle trt_handle = ActorHandle(task_names.trt);

        scope (exit) {
            db.close();
        }

        void read(dartReadRR req, immutable(DARTIndex)[] fingerprints) @safe {
            import std.algorithm;
            import tagion.hibon.HiBONtoText;
            import tagion.utils.Miscellaneous;

            RecordFactory.Recorder read_recorder = db.loads(fingerprints);
            req.respond(RecordFactory.uniqueRecorder(read_recorder));
        }

        // Checks if archives are present in database and returns all archives that were not found
        void checkRead(dartCheckReadRR req, immutable(DARTIndex)[] fingerprints) @safe {
            immutable(DARTIndex)[] check_read = (() @trusted => cast(immutable) db.checkload(fingerprints))();
            log("after checkread response");

            req.respond(check_read);
        }

        log("Starting dart with %(%02x%)", db.bullseye);

        auto hirpc = HiRPC(net);

        // Receives HiRPC requests for the dart. dartRead, dartRim, dartBullseye, dartCheckRead, search(if TRT is not enabled)
        void dartHiRPC(dartHiRPCRR req, Document doc) {
            import tagion.services.codes;
            import std.conv: to;
            import tagion.hibon.HiBONJSON;

            log("Received HiRPC request");

            if (!doc.isRecord!(HiRPC.Sender)) {
                log("wrong request sent to dartservice. Expected HiRPC.Sender got %s", doc.toPretty);
                return;
            }

            immutable receiver = hirpc.receive(doc);
            if (!(receiver.isMethod && accepted_dart_methods.canFind(receiver.method.name))) {
                log("unsupported request or method");
                const err = hirpc.error(receiver, ServiceCode.method.toString, ServiceCode.method);
                req.respond(err.toDoc);
                return;
            } 

            if (receiver.method.name == "search") {
                log("SEARCH REQUEST");

                auto owner_doc = receiver.method.params;
                Buffer[] owner_pkeys;
                foreach (owner; owner_doc[]) {
                    owner_pkeys ~= owner.get!Buffer;
                }
                auto res = db.search(owner_pkeys, net);

                Document response = hirpc.result(receiver, Document(res)).toDoc;
                req.respond(response);
                return;
            }
            Document result = db(receiver, false).toDoc;
            log("darthirpc response: %s", result.toPretty);
            req.respond(result);
        }

        // receives modify from transcript and sends the recorder onwards to the Replicator
        void modify(dartModifyRR req, immutable(RecordFactory.Recorder) recorder, immutable(long) epoch_number) @trusted {

            log("Received modify request with length=%s", recorder.length);

            immutable fingerprint_before = Fingerprint(db.bullseye);
            import core.exception : AssertError;

            try {

                auto eye = db.modify(recorder);
                log("New bullseye is %(%02x%)", eye);

                req.respond(eye);
                replicator_handle.send(SendRecorder(), recorder, eye, epoch_number);
                log.event(recorder_created, "recorder", recorder.toDoc);
                if (trt_enable) {
                    trt_handle.send(trtModify(), recorder);
                }
            }
            catch (AssertError e) {
                log("Received ASSERT ERROR bullseye before %(%02x%), %s archives that were tried to be added \n%s", fingerprint_before, e, recorder
                        .toPretty);
                fail(e);
            }
            catch (Error e) {
                log.error("DART Error %s", e);
            }

        }

        void bullseye(dartBullseyeRR req) @safe {
            auto eye = Fingerprint(db.bullseye);
            req.respond(eye);
        }

        run(&modify, &read, &checkRead, &bullseye, &dartHiRPC);

    }
}
