/// Service for validating inputs sent via socket
/// [Documentation documents/architecture/InputValidator](https://docs.tagion.org/#/documents/architecture/InputValidator)
module tagion.services.inputvalidator;

@safe:

import std.socket;
import std.stdio;
import std.algorithm : remove;
import std.conv : to;
import std.exception : assumeWontThrow;

import core.time;

import tagion.actor;
import tagion.services.messages;
import tagion.logger.Logger;
import tagion.utils.pretend_safe_concurrency;
import tagion.network.ReceiveBuffer;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.communication.HiRPC;
import tagion.basic.Debug : __write;
import tagion.utils.JSONCommon;
import tagion.services.options : TaskNames;
import tagion.crypto.SecureInterfaceNet;
import tagion.script.namerecords;
import std.format;

import nngd;

struct InputValidatorOptions {
    string sock_addr;
    uint sock_recv_timeout = 1000;
    uint sock_recv_buf = 4096;
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

enum ResponseError {
    Internal,
    InvalidBuf,
    InvalidDoc,
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
    void task(immutable(InputValidatorOptions) opts, immutable(TaskNames) task_names) @trusted {
        HiRPC hirpc = HiRPC(net);

        void reject(T)(ResponseError err_type, T data = Document()) const {
            hirpc.Error message;
            message.code = err_type;
            message.message = err_type.to!string;
            // message.data = data;
            const sender = hirpc.Sender(net, message);
            sock.send(sender.toDoc.serialize);
            log(rejected, err_type.to!string, data);
        }

        NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_REP);

        sock.sendtimeout = opts.sock_send_timeout.msecs;
        sock.recvtimeout = opts.sock_recv_timeout.msecs;
        sock.recvbuf = opts.sock_recv_buf;
        sock.sendbuf = opts.sock_send_buf;

        ReceiveBuffer buf;
        buf.max_size = opts.sock_recv_buf;

        const listening = sock.listen(opts.sock_addr);
        if (listening == 0) {
            log("listening on addr: %s", opts.sock_addr);
        }
        else {
            log.error("Failed to listen on addr: %s, %s", opts.sock_addr, nng_errstr(listening));
            throw new Exception("Failed to listen on addr: %s, %s".format(opts.sock_addr, nng_errstr(listening)));
        }
        const recv = (scope void[] b) @trusted {
            size_t ret = sock.receivebuf(cast(ubyte[]) b);
            return (ret < 0) ? 0 : cast(ptrdiff_t) ret;
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

            auto result = buf.append(recv);
            scope (failure) {
                reject(ResponseError.Internal);
            }

            if (sock.m_errno != nng_errno.NNG_OK) {
                log(rejected, "NNG_ERRNO", cast(int) sock.m_errno);
                continue;
            }

            // Fixme ReceiveBuffer .size doesn't always return correct lenght
            if (result.data.length <= 0) {
                reject(ResponseError.InvalidBuf);
                continue;
            }

            import std.exception;

            Document doc = Document(assumeUnique(result.data));
            if (doc.isInorder && doc.isRecord!(HiRPC.Sender)) {
                log("Sending contract to hirpc_verifier");
                locate(task_names.hirpc_verifier).send(inputDoc(), doc);
                const receiver = hirpc.receive(doc);
                auto response_ok = hirpc.result(receiver, ResultOk());
                sock.send(response_ok.toDoc.serialize);
            }
            else {
                reject(ResponseError.InvalidDoc, doc);
            }
        }
    }
}

alias InputValidatorHandle = ActorHandle!InputValidatorService;
