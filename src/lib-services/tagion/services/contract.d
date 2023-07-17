/// Service for verifying contracts
/// [Documentation](https://docs.tagion.org/#/documents/architecture/ContractVerifier)
module tagion.services.contract;

import std.stdio;

import tagion.actor;
import tagion.services.inputvalidator : inputDoc;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;

struct ContractService {
    void contract(inputDoc, Document doc) {
        writefln("Received document \n\t %s", doc.toPretty);
    }

    void task() nothrow {
        run(&contract);
    }
}

alias ContractServiceHandle = ActorHandle!ContractService;
