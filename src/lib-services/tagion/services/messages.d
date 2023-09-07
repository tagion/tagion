// common Message types sent between services
module tagion.services.messages;
import tagion.actor.actor;
import tagion.hibon.Document;
import tagion.script.prior.StandardRecords;

/// Generic Document sent
alias inputDoc = Msg!"inputDoc";
/// Generic HiRPC sent
alias inputHiRPC = Msg!"inputHiRPC";

/// Contracts sent to the collector
alias inputContract = Msg!"contract";
alias signedContract = Msg!"contract-S";
alias consensusContract = Msg!"contract-C";

alias inputRecorder = Msg!"recorder";

alias consensusEpoch = Msg!"consensus_epoch";
alias producedContract = Msg!"produced_contract";

/// dartCRUD
alias dartReadRR = Request!"dartRead";
alias dartCheckReadRR = Request!"dartCheckRead";
alias dartRimRR = Request!"dartRim";
alias dartBullseyeRR = Request!"dartBullseye";
alias dartModifyRR = Request!"dartModify";

alias Payload = Msg!"Payload";
alias ReceivedWavefront = Msg!"ReceivedWavefront";
alias AddedChannels = Msg!"AddedChannels";
alias BeginGossip = Msg!"BeginGossip";

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
