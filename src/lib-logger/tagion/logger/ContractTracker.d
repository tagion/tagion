module tagion.logger.ContractTracker;

import tagion.services.codes : toString;
import tagion.basic.Types : Buffer;
import tagion.hibon.HiBONRecord : HiBONRecord;
import tagion.logger.Logger;

enum ContractStatusCode {
    @("Reject") rejected,
    @("Verified") verified,
    @("Input valid") inputvalid,
    @("Signed") signed,
    @("Produced") produced,
}

@safe
string toString(ContractStatusCode code) pure nothrow {
    return code.toString!ContractStatusCode;
}

struct ContractStatus {
    Buffer contract_hash;
    ContractStatusCode status_code;
    string message;

    mixin HiBONRecord!(q{
        this(const(Buffer) contract_hash, ContractStatusCode status_code, string message) {
            this.contract_hash = contract_hash;
            this.status_code = status_code;
            this.message = message;
        }
    });
}

Topic contract_event = Topic("contract");

void logContractStatus(const(Buffer) contract_hash, ContractStatusCode status_code, string message) {
    auto status = ContractStatus(contract_hash, status_code, message);
    log.event(contract_event, "", status.toDoc);
}
