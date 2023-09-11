// Service for transcript  
/// [Documentation](https://docs.tagion.org/#/documents/architecture/transcript)
module tagion.services.transcript;

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
import tagion.services.messages;
import tagion.script.execute : ContractProduct;

/// Msg type sent to receiver task along with a hirpc

@safe
struct TranscriptOptions {
    mixin JSONCommon;
}

/**
 * TranscriptService actor
 * Receives: (inputDoc, Document)
 * Sends: (inputHiRPC, HiRPC.Receiver) to receiver_task, where Document is a correctly formatted HiRPC
**/
@safe
struct TranscriptService {
    void task(immutable(TranscriptOptions) opts) {

        void epoch(consensusEpoch, Document doc) {
        }

        void produceContract(producedContract, immutable(ContractProduct) product) {
        }

        run(&epoch, &produceContract);
    }
}

alias TranscriptServiceHandle = ActorHandle!TranscriptService;
