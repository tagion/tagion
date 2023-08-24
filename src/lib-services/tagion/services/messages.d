module tagion.services.messages;
import tagion.actor.actor;
import tagion.hibon.Document;
import tagion.script.StandardRecords;

alias inputContract = Msg!"contract";
alias inputRecorder = Msg!"recorder";

alias signedContract = Msg!"contract-S";
alias consensusContract = Msg!"contract-C";

alias consensusEpoch = Msg!"consensus_epoch";
alias producedContract = Msg!"produced_contract";

@safe
struct ContractProduct {
    CollectedSignedContract contract;
    Document[] outputs;
}

@safe
struct CollectedSignedContract {
    Document[] inputs;
    Document[] reads;
    SignedContract contract;
    //    mixin HiBONRecord;
}
