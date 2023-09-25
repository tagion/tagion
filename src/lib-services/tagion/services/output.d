module tagion.services.output;

import std.format;

import tagion.utils.JSONCommon;
import tagion.actor;
import tagion.services.messages;
import tagion.hibon.Document;
import nngd;
import core.time;
import tagion.logger.Logger;

@safe
struct OutputOptions {
    string out_sock_addr;
    string out_prefix = "OUT_";
    int socket_timeout = 1000;
    uint socket_max_buf = 4096;

    void setDefault() nothrow {
        import tagion.services.options : contract_sock_addr;

        out_sock_addr = contract_sock_addr(out_prefix);
    }

    void setPrefix(string prefix) nothrow {
        import tagion.services.options : contract_sock_addr;

        out_sock_addr = contract_sock_addr(out_prefix ~ prefix);
    }


    mixin JSONCommon;
}

@safe
struct OutputService {

    pragma(msg, "remove trusted when nng is safe");
    void task(immutable(OutputOptions) opts) @trusted {
        void checkSocketError(int rc) {
            if (rc != 0) {
                import std.format;
                throw new Exception(format("Failed to dial %s", nng_errstr(rc)));
            }

        }
        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
        int rc = sock.dial(opts.out_sock_addr);
        sock.sendtimeout = opts.socket_timeout.msecs;
        sock.sendbuf = opts.socket_max_buf;
        checkSocketError(rc);


        pragma(msg, "remove trusted when nng is safe");
        void push(HiRPCOutput, Document doc) @trusted {
            auto send_doc = doc.serialize;
            rc = sock.send(send_doc);
            checkSocketError(rc);
            log("Succesfully sent %s bytes to out socket", send_doc.length); 
        }

        run(&push);
    }


}
