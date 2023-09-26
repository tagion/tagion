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
import tagion.services.options;
import nngd;

import core.time;



@safe 
struct DARTInterfaceService {

    void task(immutable(DARTInterfaceOptions) opts, immutable(TaskNames) task_names) @trusted {

        void dartHiRPCCallback(NNGMessage *msg) @trusted {
            import tagion.hibon.HiBONJSON : toPretty;
            Document doc = msg.body_trim!(immutable(ubyte[]))(msg.length);
            log("Kernel got: %s", doc.toPretty);
            msg.clear();

            locate(task_names.dart).send(dartHiRPCRR(), doc);
            auto dart_resp = receiveOnly!(dartHiRPCRR.Response, Document);

            msg.body_append(dart_resp[1].serialize);
        }

        void checkSocketError(int rc) {
            if (rc != 0) {
                import std.format;
                throw new Exception(format("Failed to dial %s", nng_errstr(rc)));
            }

        }

        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_REP);
        sock.sendtimeout = opts.sendtimeout.msecs;
        sock.recvtimeout = 1000.msecs;
        sock.sendbuf = opts.sendbuf;

        NNGPool pool = NNGPool(&sock, cast(void function(NNGMessage*)) &dartHiRPCCallback, ulong(4));
        scope(exit) {
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

// @safe 
// void dartClientWorker(string url, Document doc) {
//     int rc;
//     NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
//     s.recvtimeout = 1000.msecs;
//     while(1) {
//         rc = s.dial(url);
//         if (rc == 0) break;
//         if(rc == nng_errno.NNG_ECONNREFUSED) {
//             nng_sleep(100.msecs);
//             continue;
//         }

//         assert(rc = 0);
//     }
//     while(1) {
//         rc = s.send(doc.serialize);
//         assert(rc = 0);
//     }

// }
