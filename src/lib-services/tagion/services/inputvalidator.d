/// Service for validating inputs sent via socket
/// https://docs.tagion.org/#/documents/architecture/InputValidator
module tagion.services.inputvalidator;

@safe:

import core.time;
import nngd;
import std.algorithm : remove;
import std.conv : to;
import std.format;
import std.socket;
import std.stdio;
import tagion.actor;
import tagion.basic.Types;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONException;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.logger.Logger;
import tagion.network.ReceiveBuffer;
import tagion.script.namerecords;
import tagion.services.messages;
import tagion.services.codes;
import tagion.services.options : TaskNames;
import tagion.utils.JSONCommon;
import tagion.utils.pretend_safe_concurrency;

struct InputValidatorOptions {
    string sock_addr;
    uint sock_recv_timeout = 1000;
    uint sock_recv_buf = 0x4000;
    uint sock_send_timeout = 200;
    uint sock_send_buf = 1024;

    import tagion.services.options : contract_sock_addr;

    void setDefault() nothrow {
        sock_addr = contract_sock_addr("CONTRACT_");
    }

    void setPrefix(string prefix) nothrow {
        sock_addr = contract_sock_addr(prefix ~ "CONTRACT_");
    }

    mixin JSONCommon;
}

/** 
 *  InputValidator actor
 *  Examples: [tagion.testbench.services.inputvalidator]
 *  Sends: (inputDoc, Document) to hirpc_verifier;
**/
struct InputValidatorService {
    const SecureNet net;
    static Topic rejected = Topic("reject/inputvalidator");

    pragma(msg, "TODO: Make inputvalidator safe when nng is");
    void task(immutable(InputValidatorOptions) opts, immutable(TaskNames) __task_names) @trusted {
        HiRPC hirpc = HiRPC(net);
        ActorHandle hirpc_verifier_handle = ActorHandle(__task_names.hirpc_verifier);

        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_REP);

        void reject(ServiceCode err_type, Document data = Document()) const nothrow {
            import tagion.services.codes;

            try {
                hirpc.Error message;
                message.code = err_type;
                debug {
                    // We send back the invalid data we received in debug mode.
                    message.message = err_type.toString;
                    message.data = data;
                }
                const sender = hirpc.Sender(net, message);
                int rc = sock.send(sender.toDoc.serialize);
                if (rc != 0) {
                    log.error("Failed to respond with rejection %s, because %s", err_type, nng_errstr(rc));
                }
                log.event(rejected, err_type.toString, data);
            }
            catch (Exception e) {
                log.error("Failed to deliver rejection %s", err_type.to!string);
            }
        }

        sock.sendtimeout = opts.sock_send_timeout.msecs;
        sock.recvtimeout = opts.sock_recv_timeout.msecs;
        sock.recvbuf = opts.sock_recv_buf;
        sock.sendbuf = opts.sock_send_buf;

        ReceiveBuffer buf;
        buf.max_size = opts.sock_recv_buf;

        const listening = sock.listen(opts.sock_addr, nonblock:
                true);
        scope (exit) {
            sock.close();
        }

        if (listening == 0) {
            log("listening on addr: %s", opts.sock_addr);
        }
        else {
            import tagion.services.exception;

            throw new ServiceException(
                    format("Failed to listen on addr: %s, %s", opts.sock_addr, nng_errstr(listening))
            );
        }
        const recv = (scope void[] b) @trusted {
            // 
            return cast(ptrdiff_t) sock.receivebuf(cast(ubyte[]) b, 0, false);
        };
        setState(Ctrl.ALIVE);
        while (!thisActor.stop) {
            // Check for control signal
            const received = receiveTimeout(
                    Duration.zero,
                    &signal,
                    &ownerTerminated,
                    &unknown
            );
            if (received) {
                continue;
            }

            version (BLOCKING) {
                scope (failure) {
                    reject(ServiceCode.internal);
                }
                auto result_buf = sock.receive!Buffer;
                if (sock.m_errno != nng_errno.NNG_OK) {
                    if (sock.m_errno != nng_errno.NNG_ETIMEDOUT) {
                        log.error(nng_errstr(sock.m_errno));
                    }
                    continue;
                }
                if (sock.m_errno == nng_errno.NNG_ETIMEDOUT) {
                    if (result_buf.length > 0) {
                        reject(ServiceCode.timeout);
                    }
                    else {
                        continue;
                    }
                }
                if (sock.m_errno != nng_errno.NNG_OK) {
                    if (sock.m_errno != nng_errno.NNG_ETIMEDOUT) {
                        log.error(nng_errstr(sock.m_errno));
                    }
                    continue;
                }
                if (result_buf.length <= 0) {
                    reject(ServiceCode.internal);
                    continue;
                }

                Document doc = result_buf;
            }
            else {
                scope (failure) {
                    reject(ServiceCode.internal);
                }
                auto result_buf = buf(recv);
                if (sock.m_errno == nng_errno.NNG_ETIMEDOUT) {
                    if (result_buf.data.length > 0) {
                        reject(ServiceCode.internal);
                    }
                    else {
                        continue;
                    }
                }
                if (sock.m_errno != nng_errno.NNG_OK) {
                    if (sock.m_errno != nng_errno.NNG_ETIMEDOUT) {
                        log.error(nng_errstr(sock.m_errno));
                    }
                    continue;
                }

                // Fixme ReceiveBuffer .size doesn't always return correct length
                if (result_buf.data.size <= 0) {
                    reject(ServiceCode.buf);
                    continue;
                }

                Document doc = result_buf.data.idup;
            }

            if (!doc.isInorder) {
                reject(ServiceCode.buf);
                continue;
            }

            if (!doc.isRecord!(HiRPC.Sender)) {
                reject(ServiceCode.hirpc, doc);
                continue;
            }
            try {
                log("Sending contract to hirpc_verifier");
                hirpc_verifier_handle.send(inputDoc(), doc);

                auto receiver = hirpc.receive(doc);
                auto response_ok = hirpc.result(receiver, ResultOk());
                sock.send(response_ok.toDoc.serialize);
            }
            catch (HiBONException _) {
                reject(ServiceCode.hibon, doc);
                continue;
            }
        }
    }
}
