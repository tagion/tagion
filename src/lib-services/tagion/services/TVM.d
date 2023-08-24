/// Service for the tagion virtual machine 
/// [Documentation](https://docs.tagion.org/#/documents/architecture/TVM)
module tagion.services.TVM;

import std.stdio;

import tagion.logger.Logger;
import tagion.basic.Debug : __write;
import tagion.utils.JSONCommon;
import tagion.actor.actor;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.services.transcript : TranscriptOptions;
import tagion.services.collector : CollectedSignedContract;
import tagion.services.messages;

/// Msg type sent to receiver task along with a hirpc
//alias contractProduct = Msg!"contract_product";
@safe
struct TVMOptions {
    string task_name = "tvm_task";
    mixin JSONCommon;
}

@safe
struct ContractProduct {
    CollectedSignedContract contract;
    Document[] outputs;
}

/**
 * TVMService actor
 * Examples: [tagion.testbench.services.hirpc_verifier]
 * Receives: (inputDoc, Document)
 * Sends: (inputHiRPC, HiRPC.Receiver) to receiver_task, where Document is a correctly formatted HiRPC
**/
@safe
struct TVMService {
    void task(immutable(TVMOptions) opts, immutable(TranscriptOptions)) {

        void contract(signedContract, immutable(CollectedSignedContract) contract) {
        }

        void consensus_contract(consensusContract, immutable(CollectedSignedContract) contract) {
        }

        run(&contract, &consensus_contract);
    }
}

alias TVMServiceHandle = ActorHandle!TVMService;
