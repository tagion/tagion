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
    int worker_timeout;
    bool trt_enable;
    TaskNames task_names;
}

/// Accepted methods for the DART.
static immutable(string[]) accepted_dart_methods = [
    Queries.dartRead,
    Queries.dartRim,
    Queries.dartBullseye,
    Queries.dartCheckRead,
];

static immutable(string[]) accepted_rep_methods = [
    "readRecorder",
];

enum RequestType {
    unknown,
    trt,
    dart,
    replicator,
}

pragma(msg, "deprecated search method should be removed from trt");
/// All methods allowed for the TRT
static immutable(string[]) accepted_trt_methods = accepted_dart_methods.map!(
    m => "trt." ~ m).array ~ "search";
/// All allowed methods for the DARTInterface
static immutable all_dartinterface_methods = accepted_dart_methods ~ accepted_trt_methods ~ accepted_rep_methods;

void set_response_doc(NNGMessage* msg, Document doc) @safe {
    msg.length = doc.full_size;
    check(msg.body_prepend(doc.serialize) == 0, "Insufficient memory");
}

void set_error_msg(NNGMessage* msg, ServiceCode err_type, string extra_msg = "") @safe {
    import tagion.services.codes;

    HiRPC.Error message;
    message.code = err_type;
    message.message = err_type.toString ~ extra_msg;
    const sender = HiRPC.Sender(null, message);
    log.error("INTERFACE ERROR: %s, %s", err_type.toString, extra_msg);
    set_response_doc(msg, sender.toDoc);
}

void task_request(alias MsgType)(string task_name, Duration timeout, Document doc, NNGMessage* msg) {
    Tid tid = locate(task_name);
    if (tid is Tid.init) {
        msg.set_error_msg(ServiceCode.internal, "Missing Tid " ~ task_name);
        return;
    }

    tid.send(MsgType(), doc);
    bool response = receiveTimeout(timeout, (MsgType.Response _, Document doc) { msg.set_response_doc(doc); });
    if (!response) {
        msg.set_error_msg(ServiceCode.timeout);
        writeln("Timeout on interface request");
        return;
    }

    writeln("Interface successful response ", task_name);
    return;
}

void hirpc_cb(NNGMessage* msg, void* ctx) @trusted {
    thread_attachThis();
    if (msg is null) {
        log.error("no message received");
        return;
    }
    if (msg.length < 1) {
        log.error("received empty msg");
        return;
    }

    thisActor.task_name = format("dart_%s", thisTid);
    auto cnt = cast(DartWorkerContext*) ctx;
    if (cnt is null) {
        log.error("the context was nil");
        return;
    }

    // we use an empty hirpc only for sending errors.
    Document doc = msg.body_trim!(immutable(ubyte[]))(msg.length);
    msg.clear();

    if (!doc.isInorder || !doc.isRecord!(HiRPC.Sender)) {
        msg.set_error_msg(ServiceCode.hirpc);
        log.error("Non-valid request received");
        return;
    }
    log("Kernel received a document");

    const empty_hirpc = HiRPC(null);

    immutable receiver = empty_hirpc.receive(doc);
    if (!receiver.isMethod) {
        msg.set_error_msg(ServiceCode.method, "Received HiRPC is not a method");
        return;
    }

    string full_name = receiver.method.full_name;
    if (accepted_trt_methods.canFind(full_name)) {
        if(!cnt.trt_enable) {
            msg.set_error_msg(ServiceCode.method, "Trt methods are not enabled");
            return;
        }
        task_request!trtHiRPCRR(cnt.task_names.trt, cnt.worker_timeout.msecs, doc, msg);
    }
    else if(accepted_rep_methods.canFind(full_name)) {
        task_request!readRecorderRR(cnt.task_names.replicator, cnt.worker_timeout.msecs, doc, msg);
    }
    else if(accepted_dart_methods.canFind(full_name)) {
        task_request!dartHiRPCRR(cnt.task_names.dart, cnt.worker_timeout.msecs, doc, msg);
    }
    else {
        msg.set_error_msg(ServiceCode.method, format("%s", all_dartinterface_methods));
    }
}

void err_cb(NNGMessage* msg, void* ctx, Exception e) @safe nothrow {
    log.fatal(e);
    try {
        msg.set_error_msg(ServiceCode.internal, e.msg);
    }
    catch (Exception e2) {
        // At this point we probably can't allocate anything, so it's better to shutdown
        fail(e2);
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
        ctx.worker_timeout = opts.sendtimeout;
        ctx.trt_enable = trt_opts.enable;
        ctx.task_names = task_names;

        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_REP);
        sock.sendtimeout = opts.sendtimeout.msecs;
        sock.recvtimeout = opts.receivetimeout.msecs;
        sock.sendbuf = opts.sendbuf;

        NNGPool pool = NNGPool(&sock, &hirpc_cb, opts.pool_size, &ctx, &err_cb);
        scope (exit) {
            pool.shutdown();
        }
        pool.start();
        auto rc = sock.listen(opts.sock_addr);
        check!ServiceError(rc == nng_errno.NNG_OK, format("Failed to listen on %s : %s", opts.sock_addr, nng_errstr(
                rc)));

        // Receive actor signals
        run();
    }

}
