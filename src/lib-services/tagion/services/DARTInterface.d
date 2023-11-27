module tagion.services.DARTInterface;

import tagion.utils.JSONCommon;

@safe
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

    mixin JSONCommon;

}

import core.time;
import nngd;
import std.format;
import tagion.actor;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.logger.Logger;
import tagion.services.messages;
import tagion.services.options;
import tagion.utils.pretend_safe_concurrency;
import tagion.services.TRTService : TRTOptions;

struct DartWorkerContext {
    string dart_task_name;
    int worker_timeout;
    bool trt_enable;
    string trt_task_name;
}

enum InterfaceError {
    Timeout,
    InvalidDoc,
    DARTLocate,
    TRTLocate,
}

void dartHiRPCCallback(NNGMessage* msg, void* ctx) @trusted {

    import std.exception;
    import std.stdio;
    import tagion.communication.HiRPC;

    HiRPC hirpc = HiRPC(null);

    void send_doc(Document doc) @trusted {
        msg.length = doc.full_size;
        msg.body_prepend(doc.serialize);
    }

    void send_error(InterfaceError err_type, string extra_msg = "") @trusted {
        import std.conv;

        hirpc.Error message;
        message.code = err_type;
        message.message = err_type.to!string ~ extra_msg;
        const sender = hirpc.Sender(null, message);
        writefln("INTERFACE ERROR: %s", err_type.to!string ~ extra_msg);
        send_doc(sender.toDoc);
        // msg.body_append(sender.toDoc.serialize);
    }

    void dartHiRPCResponse(dartHiRPCRR.Response res, Document doc) @trusted {
        writeln("Interface successful response");
        send_doc(doc);
        // msg.body_append(doc.serialize);
    }

    void trtHiRPCResponse(trtHiRPCRR.Response res, Document doc) @trusted {
        writeln("TRT Inteface succesful response");
        send_doc(doc);
    }

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
        send_error(InterfaceError.InvalidDoc);
        writeln("Non-valid request received");
        return;
    }
    writeln("Kernel received a document");

    const empty_hirpc = HiRPC(null);

    immutable receiver = empty_hirpc.receive(doc);
    if (receiver.method.name == "search" && cnt.trt_enable) {
        writeln("TRT SEARCH REQUEST");
        auto trt_tid = locate(cnt.trt_task_name);
        if (trt_tid is Tid.init) {
            send_error(InterfaceError.TRTLocate, cnt.trt_task_name);
            return;
        }
        trt_tid.send(trtHiRPCRR(), doc);
        auto trt_resp = receiveTimeout(cnt.worker_timeout.msecs, &trtHiRPCResponse);
        if (!trt_resp) {
            send_error(InterfaceError.Timeout);
            writeln("Timeout on trt request");
            return;
        }

    }
    else {
        auto dart_tid = locate(cnt.dart_task_name);
        if (dart_tid is Tid.init) {
            send_error(InterfaceError.DARTLocate, cnt.dart_task_name);
            return;
        }
        dart_tid.send(dartHiRPCRR(), doc);
        auto dart_resp = receiveTimeout(cnt.worker_timeout.msecs, &dartHiRPCResponse);
        if (!dart_resp) {
            send_error(InterfaceError.Timeout);
            writeln("Timeout on dart request");
            return;
        }

    }
}

@safe
struct DARTInterfaceService {
    immutable(DARTInterfaceOptions) opts;
    immutable(TRTOptions) trt_opts;
    immutable(TaskNames) task_names;

    void task() @trusted {

        void checkSocketError(int rc) {
            if (rc != 0) {
                import std.format;

                throw new Exception(format("Failed to dial %s", nng_errstr(rc)));
            }

        }

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
        checkSocketError(rc);

        setState(Ctrl.ALIVE);

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
        }

    }

}
