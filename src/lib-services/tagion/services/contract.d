/// Service for verifying contracts
/// [Documentation](https://docs.tagion.org/#/documents/architecture/ContractVerifier)
module tagion.services.contract;

import std.stdio;

import tagion.actor;
import tagion.services.inputvalidator : inputDoc;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;

struct ContractService {
static:
    void contract(inputDoc, Document doc) {
        writefln("Received document \n\t %s", doc.toPretty);
    }

    void task(string task_name) nothrow {
        scope (exit) {
            end();
        }
        run(task_name, &contract);
    }
}

alias ContractServiceHandle = ActorHandle!ContractService;
