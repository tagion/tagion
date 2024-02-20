// Transaction reverse table service using a DART
module tagion.services.TRTService;
import tagion.services.options : TaskNames;

import std.algorithm : map, filter, canFind;
import std.array;
import std.exception;
import std.file;
import std.format : format;
import std.path : isValidPath;
import std.path;
import std.stdio;
import std.range : enumerate;
import tagion.actor;
import tagion.basic.Types : FileExtension;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.DART;
import tagion.dart.DARTBasic : DARTIndex, dartIndex, dartKey;
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
import tagion.basic.Types;
import tagion.trt.TRT;
import tagion.hibon.HiBON;
import tagion.script.standardnames;
import tagion.services.exception;
import tagion.services.DART : accepted_dart_methods;

@safe
struct TRTOptions {
    bool enable = true;
    string folder_path = buildPath(".");
    string trt_filename = "trt".setExtension(FileExtension.dart);

    string trt_path() inout nothrow {
        return buildPath(folder_path, trt_filename);
    }

    void setPrefix(string prefix) nothrow {
        trt_filename = prefix ~ trt_filename;
    }

    mixin JSONCommon;
}

@safe
struct TRTService {
    static Topic trt_created = Topic("trt_created");
    void task(immutable(TRTOptions) opts, immutable(TaskNames) task_names, shared(StdSecureNet) shared_net) {
        DART trt_db;
        Exception dart_exception;

        const net = new StdSecureNet(shared_net);
        auto rec_factory = RecordFactory(net);
        auto hirpc = HiRPC(net);
        ActorHandle dart_handle = ActorHandle(task_names.dart);

        check(opts.trt_path.exists, format("TRT database %s file not found", opts.trt_path));
        log("TRT PATH FOR DATABASE=%s", opts.trt_path);
        trt_db = new DART(net, opts.trt_path, dart_exception);
        if (dart_exception !is null) {
            throw dart_exception;
        }

        scope (exit) {
            trt_db.close();
        }

        struct TRTRequest {
            trtHiRPCRR req;
            Document doc;
        }

        TRTRequest[uint] requests;

        log("%s, starting trt with %(%02x%)", opts.trt_path, trt_db.bullseye);

        void receive_recorder(dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) {
            log("receive_recorder from dartread");
            if (!(res.id in requests)) {
                return;
            }
            HiBON params = new HiBON;
            foreach (i, bill; recorder[].enumerate) {
                params[i] = bill.filed;
            }

            auto client_request = requests[res.id];
            scope (exit) {
                requests.remove(res.id);
            }

            immutable receiver = hirpc.receive(client_request.doc);

            Document response = hirpc.result(receiver, params).toDoc;
            client_request.req.respond(response);
        }

        void trt_read(trtHiRPCRR client_req, Document doc) {
            import tagion.services.codes;
            import std.conv : to;
            log("trt_read request");
            if (!doc.isRecord!(HiRPC.Sender)) {
                return;
            }
            log("before hirpc");
            immutable receiver = hirpc.receive(doc);

            if (!(receiver.isMethod && accepted_dart_methods.canFind(receiver.method.name))) {
                log("received non valid HIRPC method");
                const err = hirpc.error(receiver, ServiceCode.method.toString, ServiceCode.method);
                client_req.respond(err.toDoc);
                return;
            }
            log("before owner doc");
            if (receiver.method.name == "search") {
                auto owner_doc = receiver.method.params;
                if (owner_doc[].empty) {
                    import tagion.services.DARTInterface;
                    import std.conv : to;

                    log("the owner doc was empty");
                    const err = hirpc.error(receiver, ServiceCode.params.toString, ServiceCode.params);
                    client_req.respond(err.toDoc);
                    return;
                }

                log("before creating indices");
                auto owner_indices = owner_doc[]
                    .map!(owner => net.dartKey(TRTLabel, Pubkey(owner.get!Buffer)))
                    .array;

                import std.algorithm;

                owner_indices.each!(o => writefln("%(%02x%)", o));

                auto trt_read_recorder = trt_db.loads(owner_indices);
                immutable(DARTIndex)[] indices;
                foreach (a; trt_read_recorder[]) {
                    indices ~= TRTArchive(a.filed).indices.map!(d => cast(immutable) DARTIndex(d))
                        .array;
                }

                if (indices.empty) {
                    Document response = hirpc.result(receiver, Document()).toDoc;
                    client_req.respond(response);
                    return;
                }

                log("sending dartread request");
                auto dart_req = dartReadRR();
                requests[dart_req.id] = TRTRequest(client_req, doc);

                dart_handle.send(dart_req, indices);
                return;
            }
            Document result = trt_db(receiver, false).toDoc;
            client_req.respond(result);
        }

        void modify(trtModify, immutable(RecordFactory.Recorder) dart_recorder) {
            log("modify request from dart");
            auto trt_recorder = rec_factory.recorder;

            // get a recorder from all the dartkeys already in the db for the function
            auto index_lookup = dart_recorder[]
                .filter!(a => a.filed.hasMember(StdNames.owner))
                .map!(a => Document(a.filed))
                .map!(doc => net.dartKey(TRTLabel, doc[StdNames.owner].get!Pubkey));

            auto already_in_dart = trt_db.loads(index_lookup);

            createTRTUpdateRecorder(dart_recorder, already_in_dart, trt_recorder, net);
            if (!trt_recorder.empty) {
                log("trt recorder modify %s", trt_recorder.toPretty);
                trt_db.modify(trt_recorder);
                log.event(trt_created, "trt_created", trt_recorder.toDoc);
            }
        }

        run(&modify, &trt_read, &receive_recorder);

    }

}
