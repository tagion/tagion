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
import tagion.script.StandardRecords;
import tagion.network.ReceiveBuffer;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.communication.HiRPC;
import tagion.basic.Debug : __write;
import tagion.utils.JSONCommon;

import nngd;

@safe
struct InputValidatorOptions {
    string sock_addr;
    uint socket_select_timeout = 1000; // msecs
    void setDefault() nothrow {
        import tagion.services.options : contract_sock_path;

        sock_addr = contract_sock_path;
        socket_select_timeout = 1000;
    }

    mixin JSONCommon;
}

/** 
 *  InputValidator actor
 *  Examples: [tagion.testbench.services.inputvalidator]
 *  Sends: (inputDoc, Document) to receiver_task;
**/
struct InputValidatorService {
    void task(immutable(InputValidatorOptions) opts, string receiver_task) {
        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
        ReceiveBuffer buf;
        s.recvtimeout = opts.socket_select_timeout.msecs;
        const listening = s.listen(opts.sock_addr);
        if (listening == 0) {
            log("listening on addr: %s", opts.sock_addr);
        }
        else {
            log.error("Failed to listen on addr: %s, %s", opts.sock_addr, nng_errstr(listening));
            assert(0); // fixme
        }
        const recv = (void[] b) @trusted {
            size_t ret = s.receivebuf(cast(ubyte[]) b);
            return (ret < 0) ? 0 : cast(ptrdiff_t) ret;
        };
        setState(Ctrl.ALIVE);
        while (!thisActor.stop) {
            auto result = buf.append(recv);
            if (s.m_errno != nng_errno.NNG_OK) {
                log.error("Failed to receive: %s", s.m_errno, nng_errstr(s.m_errno));
                // fail()
            }

            if (result.size != 0) {
                Document doc = Document(cast(immutable) result.data);
                __write("Received %d bytes.", result.size);
                __write("Document status code %s", doc.valid);

                if (doc.valid is Document.Element.ErrorCode.NONE
                        && doc.isRecord!(HiRPC.Sender)) {
                    __write("sending to %s", receiver_task);
                    locate(receiver_task).send(inputDoc(), doc);
                }
            }

            // Check for control signal
            receiveTimeout(
                    Duration.zero,
                    &signal,
                    &ownerTerminated,
                    &unknown
            );
        }
        log("RR: bye!");
    }
}

alias InputValidatorHandle = ActorHandle!InputValidatorService;
