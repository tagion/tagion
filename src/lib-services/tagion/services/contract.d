/// Service for verifying contracts
/// [Documentation](https://docs.tagion.org/#/documents/architecture/ContractVerifier)
module tagion.services.contract;

import std.stdio;

import tagion.utils.pretend_safe_concurrency;
import tagion.actor;
import tagion.basic.Debug : __write;
import tagion.services.inputvalidator : inputDoc;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;

/// Msg type sent to receiver task along with a hirpc
alias inputHiRPC = Msg!"inputHiRPC";

struct ContractService {
    string receiver_task;
    void task(string receiver_task, immutable(SecureNet) net) {
        receiver_task = receiver_task;
        const hirpc = HiRPC(net);

        void contract(inputDoc, Document doc) {
            __write("Received document \n%s", doc.toPretty);
            if(!doc.isRecord!(HiRPC.Sender)) {
                return;
            }
            HiRPC.Sender sender = hirpc.act(doc);
            if (sender.isSigned) {
                locate(receiver_task).send(inputHiRPC(), doc);
            }
        }

        run(&contract);
    }
}

alias ContractServiceHandle = ActorHandle!ContractService;
