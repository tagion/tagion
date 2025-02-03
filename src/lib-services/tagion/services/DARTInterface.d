/// Service which exposes dart reads over a socket
/// https://docs.tagion.org/tech/architecture/DartInterface
module tagion.services.DARTInterface;
 
@safe:

import core.time;
import core.thread;

import std.array;
import std.algorithm : map, canFind, startsWith;
import std.stdio;
import std.format;
import std.exception : assumeWontThrow;

import tagion.actor;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.logger.Logger;
import tagion.services.messages;
import tagion.services.codes;
import tagion.services.options;
import tagion.utils.pretend_safe_concurrency;
import tagion.services.TRTService : TRTOptions;
import tagion.dart.DARTBasic;
import tagion.json.JSONRecord;

import nngd;

struct DARTInterfaceOptions {
    import tagion.services.options : contract_sock_addr;

    string sock_addr;
    string dart_prefix = "DART_";
    int sendtimeout = 10_000;
    int receivetimeout = 1000;
    uint pool_size = 12;
    uint sendbuf = 0x2_0000;

    void setDefault() nothrow {
        sock_addr = contract_sock_addr(dart_prefix);
    }

    void setPrefix(string prefix) nothrow {
        sock_addr = contract_sock_addr(prefix ~ dart_prefix);
    }

    mixin JSONRecord;

}

struct DartWorkerContext {
    string dart_task_name;
    int worker_timeout;
    bool trt_enable;
    string trt_task_name;
}

/// Accepted methods for the DART.
static immutable(string[]) accepted_dart_methods = [
    Queries.dartRead, 
    Queries.dartRim, 
    Queries.dartBullseye, 
    Queries.dartCheckRead, 
];

pragma(msg, "deprecated search method should be removed from trt");
/// All methods allowed for the TRT
static immutable(string[]) accepted_trt_methods = accepted_dart_methods.map!(m => "trt." ~ m).array ~ "search";
/// All allowed methods for the DARTInterface
static immutable all_dartinterface_methods = accepted_dart_methods ~ accepted_trt_methods;

void dartHiRPCCallback(NNGMessage* msg, void* ctx) @trusted {
    void set_response_doc(Document doc) @trusted {
        msg.length = doc.full_size;
        msg.body_prepend(doc.serialize);
    }

    void set_error_msg(ServiceCode err_type, string extra_msg = "") @safe {
        import tagion.services.codes;
        HiRPC.Error message;
        message.code = err_type;
        message.message = err_type.toString ~ extra_msg;
        const sender = HiRPC.Sender(null, message);
        log("INTERFACE ERROR: %s, %s", err_type.toString, extra_msg);
        set_response_doc(sender.toDoc);
    }

    void dart_hirpc_response(dartHiRPCRR.Response, Document doc) @safe {
        set_response_doc(doc);
    }

    void trt_hirpc_response(trtHiRPCRR.Response, Document doc) @safe {
        set_response_doc(doc);
    }

    try {
        thread_attachThis();

        if (msg is null) {
            writeln("no message received");
            return;
        }
        if (msg.length < 1) {
            writeln("received empty msg");
            return;
        }

        thisActor.task_name = format("%s", thisTid);
        auto cnt = cast(DartWorkerContext*) ctx;
        if (cnt is null) {
            writeln("the context was nil");
            return;
        }

        // we use an empty hirpc only for sending errors.
        Document doc = msg.body_trim!(immutable(ubyte[]))(msg.length);
        msg.clear();

        if (!doc.isInorder || !doc.isRecord!(HiRPC.Sender)) {
            set_error_msg(ServiceCode.hirpc);
            writeln("Non-valid request received");
            return;
        }
        writeln("Kernel received a document");

        const empty_hirpc = HiRPC(null);

        immutable receiver = empty_hirpc.receive(doc);
        if (!(receiver.isMethod && all_dartinterface_methods.canFind(receiver.method.full_name))) {
            set_error_msg(ServiceCode.method, format("%s", all_dartinterface_methods));
            return;
        }

        const is_trt_req = accepted_trt_methods.canFind(receiver.method.full_name);
        string request_task_name = is_trt_req ? cnt.trt_task_name : cnt.dart_task_name;
        Tid tid = locate(request_task_name);

        if (tid is Tid.init) {
            set_error_msg(ServiceCode.internal, "Missing Tid " ~ request_task_name);
            return;
        }

        bool response;
        if (is_trt_req) {
            tid.send(trtHiRPCRR(), doc); 
            response = receiveTimeout(cnt.worker_timeout.msecs, &trt_hirpc_response);

        } else {
            tid.send(dartHiRPCRR(), doc); 
            response = receiveTimeout(cnt.worker_timeout.msecs, &dart_hirpc_response);
        }

        if (!response) {
            set_error_msg(ServiceCode.timeout);
            writeln("Timeout on interface request");
            return;
        }

        writeln("Interface successful response ", receiver.method.full_name);
    } catch(Exception e) {
        assumeWontThrow(set_error_msg(ServiceCode.internal, e.msg));
    }
}

import tagion.services.exception;
import tagion.errors.tagionexceptions;

struct DARTInterfaceService {
    immutable(DARTInterfaceOptions) opts;
    immutable(TRTOptions) trt_opts;
    immutable(TaskNames) task_names;

    pragma(msg, "FIXME: make dart interface @safe when nng is");
    void task() @trusted {
        setState(Ctrl.STARTING);

        DartWorkerContext ctx;
        ctx.dart_task_name = task_names.dart;
        ctx.worker_timeout = opts.sendtimeout;
        ctx.trt_task_name = task_names.trt;
        ctx.trt_enable = trt_opts.enable;

        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_REP);
        sock.sendtimeout = opts.sendtimeout.msecs;
        sock.recvtimeout = opts.receivetimeout.msecs;
        sock.sendbuf = opts.sendbuf;

        NNGPool pool = NNGPool(&sock, &dartHiRPCCallback, opts.pool_size, &ctx);
        scope (exit) {
            pool.shutdown();
        }
        pool.init();
        auto rc = sock.listen(opts.sock_addr);
        check!ServiceError(rc == nng_errno.NNG_OK, format("Failed to dial %s", nng_errstr(rc)));

        // Receive actor signals
        run();
    }

}
