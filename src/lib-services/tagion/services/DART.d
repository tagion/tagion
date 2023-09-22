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

@safe
struct DARTOptions {
    string dart_filename = buildPath(".", "dart".setExtension(FileExtension.dart));

    void setPrefix(string prefix) nothrow {
        import std.exception;

        dart_filename = buildPath(".", assumeWontThrow(format("%sdart", prefix)).setExtension(FileExtension.dart));
    }

    mixin JSONCommon;
}

@safe
struct DARTService {
    void task(immutable(DARTOptions) opts, immutable(SecureNet) net) {
        DART db;
        Exception dart_exception;
        db = new DART(net, opts.dart_filename);
        if (dart_exception !is null) {
            throw dart_exception;
        }

        scope (exit) {
            db.close();
        }

        void read(dartReadRR req, immutable(DARTIndex)[] fingerprints) @safe {
            RecordFactory.Recorder read_recorder = db.loads(fingerprints, Archive.Type.NONE);
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
            writeln("INSIDE DARTHIRPC");
            if (!doc.isRecord!(HiRPC.Sender)) {
                import tagion.hibon.HiBONJSON;
                assert(0, format("wrong request sent to dartservice. Expected HiRPC.Sender got %s", doc.toPretty));
            }

            immutable receiver = empty_hirpc.receive(doc);

            assert(receiver.method.name == DART.Quries.dartRead || receiver.method.name == DART.Quries.dartRim, "unsupported hirpc request");

            auto result = db(receiver, false);
            req.respond(result.message[Keywords.result].get!Document);
        }

        
        // only used from the outside
        void rim(dartRimRR req, DART.Rims rims) {

            // empty  
        }

        void modify_request(dartModifyRR req, immutable(RecordFactory.Recorder) recorder) @safe {
            immutable eye = DARTIndex(db.modify(recorder));
            req.respond(eye);
        }

        void modify(dartModify, immutable(RecordFactory.Recorder) recorder) @safe {
            db.modify(recorder);
        }

        void bullseye(dartBullseyeRR req) @safe {
            immutable eye = DARTIndex(db.bullseye);
            req.respond(eye);
        }

        run(&read, &checkRead, &modify_request, &modify, &bullseye, &dartHiRPC);

    }
}

alias DARTServiceHandle = ActorHandle!DARTService;
