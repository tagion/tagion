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


struct DartWorkerContext {
    string dart_task_name;
    int dart_worker_timeout;
}

enum InterfaceError {
    Timeout,
    InvalidDoc,
    DARTLocate,
}



void dartHiRPCCallback(NNGMessage *msg, void *ctx) @trusted {

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

    auto dart_tid = locate(cnt.dart_task_name);
    if (dart_tid is Tid.init) {
        send_error(InterfaceError.DARTLocate, cnt.dart_task_name);
        return;
    }
    
    dart_tid.send(dartHiRPCRR(), doc);
    auto dart_resp = receiveTimeout(cnt.dart_worker_timeout.msecs, &dartHiRPCResponse);
    if (!dart_resp) {
        send_error(InterfaceError.Timeout);
        writeln("Timeout on dart request");
        return;
    }
}

@safe
struct DARTInterfaceService {
    immutable(DARTInterfaceOptions) opts;
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
        ctx.dart_worker_timeout = opts.sendtimeout;

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

alias DARTInterfaceServiceHandle = ActorHandle!DARTInterfaceService;
