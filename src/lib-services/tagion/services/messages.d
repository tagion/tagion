module tagion.services.messages;
import tagion.actor.actor;
import tagion.hibon.Document;
import tagion.script.StandardRecords;

/// Msg Type sent to actors who receive the document
alias inputDoc = Msg!"inputDoc";
/// Msg type sent to receiver task along with a hirpc
alias inputHiRPC = Msg!"inputHiRPC";

alias inputContract = Msg!"contract";
alias inputRecorder = Msg!"recorder";

alias signedContract = Msg!"contract-S";
alias consensusContract = Msg!"contract-C";

alias consensusEpoch = Msg!"consensus_epoch";
alias producedContract = Msg!"produced_contract";

alias dartReadRR = Request!"dartRead";
alias dartCheckReadRR = Request!"dartCheckRead";
alias dartRimRR = Request!"dartRim";
alias dartBullseyeRR = Request!"dartBullseye";
alias dartModifyRR = Request!"dartModify";

alias Payload = Msg!"Payload";
alias ReceivedWavefront = Msg!"ReceivedWavefront";
alias AddedChannels = Msg!"AddedChannels";

@safe
struct ContractProduct {
    immutable(CollectedSignedContract*) contract;
    Document[] outputs;
}

@safe
struct CollectedSignedContract {
    Document[] inputs;
    Document[] reads;
    SignedContract contract;
    //mixin HiBONRecord;
}
