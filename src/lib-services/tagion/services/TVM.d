/// Service for the tagion virtual machine 
/// [Documentation](https://docs.tagion.org/#/documents/architecture/TVM)
module tagion.services.TVM;

import std.stdio;
import core.time;

import tagion.logger.Logger;
import tagion.basic.Debug : __write;
import tagion.actor.actor;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.services.options;
import tagion.services.messages;
import tagion.logger.Logger;

/// Msg type sent to receiver task along with a hirpc
//alias contractProduct = Msg!"contract_product";
@safe
struct TVMOptions {
    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

/**
 * TVMService actor
**/
@safe
struct TVMService {
    void task(immutable(TVMOptions) opts, immutable(Options.TranscriptOptions)) {

        void contract(signedContract, immutable(CollectedSignedContract) contract) {
        }

        void consensus_contract(consensusContract, immutable(CollectedSignedContract) contract) {
        }

        void timeout() {
            log("Time out");
        }

        run(&contract, &consensus_contract);
        //runTimeout(100.msecs, &timeout);   
    }
}

alias TVMServiceHandle = ActorHandle!TVMService;
