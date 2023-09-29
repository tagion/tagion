module tagion.services.DARTInterface;

import tagion.utils.JSONCommon;

@safe
struct DARTInterfaceOptions {
    string sock_addr;
    string dart_prefix = "DART_";
    int sendtimeout = 1000;
    uint sendbuf = 4096;

    void setDefault() nothrow {
        import tagion.services.options : contract_sock_addr;

        sock_addr = contract_sock_addr(dart_prefix);
    }

    void setPrefix(string prefix) nothrow {
        import tagion.services.options : contract_sock_addr;

        sock_addr = contract_sock_addr(dart_prefix ~ prefix);
    }

    mixin JSONCommon;

}

import tagion.actor;
import tagion.utils.pretend_safe_concurrency;
import tagion.logger.Logger;
import tagion.services.messages;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.services.options;
import nngd;

import core.time;

pragma(msg, "fixme(pr): temporary shared name");

struct dartWorkerContext {
    string dart_task_name;
}

void dartHiRPCCallback(NNGMessage* msg, void* ctx) @trusted {
    thisActor.task_name = format("%s", thisTid);
    // log.register(thisActor.task_name);
    import std.stdio;

    auto cnt = cast(dartWorkerContext*) ctx;

    import tagion.hibon.HiBONJSON : toPretty;
    import tagion.communication.HiRPC;

    if (msg.length == 0) {
        writeln("received empty msg");
        return;
    }
    Document doc = msg.body_trim!(immutable(ubyte[]))(msg.length);
    msg.clear();

    writefln("Kernel got: %s", doc.toPretty);
    if (!doc.isInorder || !doc.isRecord!(HiRPC.Sender)) {
        // log("Non-valid request received");
        return;
    }
    locate(cnt.dart_task_name).send(dartHiRPCRR(), doc);

    void dartHiRPCResponse(dartHiRPCRR.Response res, Document doc) {
        msg.body_append(doc.serialize);
    }

    auto dart_resp = receiveTimeout(100.msecs, &dartHiRPCResponse);
    if (!dart_resp) {
        writefln("Non-valid request received");
        return;
        // send a error;
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

        dartWorkerContext ctx;
        ctx.dart_task_name = task_names.dart;

        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_REP);
        sock.sendtimeout = opts.sendtimeout.msecs;
        sock.recvtimeout = 1000.msecs;
        sock.sendbuf = opts.sendbuf;

        NNGPool pool = NNGPool(&sock, &dartHiRPCCallback, 4, &ctx);
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

            // Document doc = sock.receive!Document;

        }

    }

}

alias DARTInterfaceServiceHandle = ActorHandle!DARTInterfaceService;
