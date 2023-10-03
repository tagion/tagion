/// Service for validating inputs sent via socket
/// [Documentation documents/architecture/InputValidator](https://docs.tagion.org/#/documents/architecture/InputValidator)
module tagion.services.inputvalidator;

import std.socket;
import std.stdio;
import std.algorithm : remove;

import core.time;

import tagion.actor;
import tagion.services.messages;
import tagion.logger.Logger;
import tagion.utils.pretend_safe_concurrency;
import tagion.script.prior.StandardRecords;
import tagion.network.ReceiveBuffer;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.communication.HiRPC;
import tagion.basic.Debug : __write;
import tagion.utils.JSONCommon;
import tagion.services.options : TaskNames;

import nngd;

@safe
struct InputValidatorOptions {
    string sock_addr;
    void setDefault() nothrow {
        import tagion.services.options : contract_sock_addr;

        sock_addr = contract_sock_addr;
    }

    void setPrefix(string prefix) nothrow {
        import tagion.services.options : contract_sock_addr;

        sock_addr = contract_sock_addr(prefix);
    }

    mixin JSONCommon;
}

enum reject_inputvalidator = "reject/inputvalidator";
/** 
 *  InputValidator actor
 *  Examples: [tagion.testbench.services.inputvalidator]
 *  Sends: (inputDoc, Document) to hirpc_verifier;
**/
@safe
struct InputValidatorService {
    pragma(msg, "TODO: Make inputvalidator safe when nng is");
    void task(immutable(InputValidatorOptions) opts, immutable(TaskNames) task_names) @trusted {
        auto rejected = submask.register(reject_inputvalidator);
        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
        ReceiveBuffer buf;
        // s.recvtimeout = opts.socket_select_timeout.msecs;
        const listening = s.listen(opts.sock_addr);
        if (listening == 0) {
            log("listening on addr: %s", opts.sock_addr);
        }
        else {
            log.error("Failed to listen on addr: %s, %s", opts.sock_addr, nng_errstr(listening));
            throw new Exception("Failed to listen on addr: %s, %s".format(opts.sock_addr, nng_errstr(listening)));
        }
        const recv = (scope void[] b) @trusted {
            size_t ret = s.receivebuf(cast(ubyte[]) b);
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
            if (s.m_errno != nng_errno.NNG_OK) {
                log(rejected, "NNG_ERRNO", cast(int) s.m_errno);
                continue;
            }

            // Fixme ReceiveBuffer .size doesn't always return correct lenght
            if (result.data.length <= 0) {
                log(rejected, "invalid_buf", result.size);
                continue;
            }

            import std.exception;

            Document doc = Document(assumeUnique(result.data));
            if (doc.isInorder && doc.isRecord!(HiRPC.Sender)) {
                log("Sending contract to hirpc_verifier");
                locate(task_names.hirpc_verifier).send(inputDoc(), doc);
            }
            else {
                log(rejected, "invalid_doc", doc);
            }
        }
    }
}

alias InputValidatorHandle = ActorHandle!InputValidatorService;
