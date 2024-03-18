/// Service for verifying contracts
/// https://docs.tagion.org/docs/architecture/HiRPCVerifier
module tagion.services.hirpc_verifier;

import std.stdio;
import tagion.actor.actor;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.logger.Logger;
import tagion.script.common : SignedContract;
import tagion.services.messages;
import tagion.services.codes;
import tagion.utils.JSONCommon;
import tagion.utils.pretend_safe_concurrency;

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

/**
 * HiRPCVerifierService actor
 * Examples: [tagion.testbench.services.hirpc_verifier]
 * Receives: (inputDoc, Document)
 * Sends: (inputHiRPC, HiRPC.Receiver) to collector_task, where Document is a correctly formatted HiRPC
**/
@safe
struct HiRPCVerifierService {
    import tagion.services.options : TaskNames;

    void task(immutable(HiRPCVerifierOptions) opts, immutable(TaskNames) task_names) {

        SecureNet net = new StdSecureNet;
        const hirpc = HiRPC(net);
        immutable collector_task = task_names.collector;

        void reject(ServiceCode reason, lazy Document doc) @safe {
            if (opts.send_rejected_hirpcs) {
                locate(opts.rejected_hirpcs).send(reason, doc);
            }
        }

        void contract(inputDoc, Document doc) @safe {
            if (!doc.isRecord!(HiRPC.Sender)) {
                reject(ServiceCode.hirpc, doc);
                return;
            }

            const receiver = hirpc.receive(doc);
            if (!receiver.isMethod) {
                reject(ServiceCode.method, doc);
                return;
            }

            switch (receiver.method.name) {
            case ContractMethods.submit:
                if (!(Document(receiver.method.params).isRecord!SignedContract)) {
                    reject(ServiceCode.params, doc);
                    return;
                }
                if (receiver.signed is HiRPC.SignedState.VALID) {
                    log("sending contract to collector");
                    locate(collector_task).send(inputHiRPC(), receiver);
                }
                else {
                    reject(ServiceCode.sign, doc);
                }
                break;
            default:
                reject(ServiceCode.method, doc);
                break;
            }
        }

        run(&contract);
    }
}
