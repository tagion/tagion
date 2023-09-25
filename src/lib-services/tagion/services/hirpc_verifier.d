/// Service for verifying contracts
/// [Documentation](https://docs.tagion.org/#/documents/architecture/HiRPCVerifier)
module tagion.services.hirpc_verifier;

import std.stdio;

import tagion.services.messages;
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

struct HiRPCVerifierOptions {
    /// Rejected documents won be discarded and instead sent to rejected_contracts_task
    bool send_rejected_hirpcs = false;
    /// Which task to send rejected document to;
    string rejected_hirpcs = "";
    mixin JSONCommon;
}

/// HiRPC methods
enum ContractMethods {
    submit = "submit",
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
 * Sends: (inputHiRPC, HiRPC.Receiver) to collector_task, where Document is a correctly formatted HiRPC
**/
@safe
struct HiRPCVerifierService {
    import tagion.services.options : TaskNames;

    void task(immutable(HiRPCVerifierOptions) opts, immutable(TaskNames) task_names, immutable(SecureNet) net) {
        const hirpc = HiRPC(net);
        immutable collector_task = task_names.collector;

        void reject(RejectReason reason, lazy Document doc) @safe {
            if (opts.send_rejected_hirpcs) {
                locate(opts.rejected_hirpcs).send(reason, doc);
            }
        }

        void contract(inputDoc, Document doc) @safe {
            debug log("Received document \n%s", doc.toPretty);

            if (!doc.isRecord!(HiRPC.Sender)) {
                reject(RejectReason.notAHiRPC, doc);
                return;
            }

            const receiver = hirpc.receive(doc);

            import tagion.dart.DART;

            switch (receiver.method.name) {
            case ContractMethods.submit:
                if (receiver.signed is HiRPC.SignedState.VALID) {
                    locate(collector_task).send(inputHiRPC(), receiver);
                }
                else {
                    reject(RejectReason.notSigned, doc);
                }
                break;
            case DART.Queries.dartRead, DART.Queries.dartBullseye:
                auto dart_hirpc = dartHiRPCRR();
                pragma(msg, "TODO(pr): relay to shell service?");
                // locate(dart_task_name).send(dart_hirpc, doc);
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
