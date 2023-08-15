/// Service for verifying contracts
/// [Documentation](https://docs.tagion.org/#/documents/architecture/HiRPCVerifier)
module tagion.services.hirpc_verifier;

import std.stdio;

import tagion.logger.Logger;
import tagion.basic.Debug : __write;
import tagion.utils.JSONCommon;
import tagion.utils.pretend_safe_concurrency;
import tagion.actor.actor;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
public import tagion.services.inputvalidator : inputDoc;

/// Msg type sent to receiver task along with a hirpc
alias inputHiRPC = Msg!"inputHiRPC";

struct HiRPCVerifierOptions {
    /// Rejected documents won be discarded and instead sent to rejected_contracts_task
    bool send_rejected_hirpcs = false;
    /// Which task to send rejected document to;
    string rejected_hirpcs = "";
    mixin JSONCommon;
}

/// HiRPC methods
enum ContractMethods {
    transaction = "transaction",
}

/// used internally in combination with `send_rejected_contracts` optios for testing & tracing that contracts are correctly rejected
enum RejectReason {
    notAHiRPC, // The Document received was not a vald HiRPC
    invalidMethod, // The method was not one of the accepted methods
    notSigned, // The rpc was not signed when it should have been
}

/**
 * HiRPCVerifierService actor
 * Examples: [tagion.testbench.services.hirpc_verifier]
 * Receives: (inputDoc, Document)
 * Sends: (inputHiRPC, HiRPC.Receiver) to receiver_task, where Document is a correctly formatted HiRPC
**/
struct HiRPCVerifierService {
    void task(immutable(HiRPCVerifierOptions) opts, string receiver_task, immutable(SecureNet) net) {
        const hirpc = HiRPC(net);

        void reject(RejectReason reason, lazy Document doc) {
            if (opts.send_rejected_hirpcs) {
                locate(opts.rejected_hirpcs).send(reason, doc);
            }
        }

        void contract(inputDoc, Document doc) {
            debug log("Received document \n%s", doc.toPretty);

            if (!doc.isRecord!(HiRPC.Sender)) {
                reject(RejectReason.notAHiRPC, doc);
                return;
            }

            const receiver = hirpc.receive(doc);
            with (ContractMethods) switch (receiver.method.name) {
            case transaction:
                if (receiver.signed is HiRPC.SignedState.VALID) {
                    locate(receiver_task).send(inputHiRPC(), receiver);
                }
                else {
                    reject(RejectReason.notSigned, doc);
                }
                break;
            default:
                reject(RejectReason.invalidMethod, doc);
                break;
            }
        }

        run(&contract);
    }
}

alias HiRPCVerifierServiceHandle = ActorHandle!HiRPCVerifierService;
