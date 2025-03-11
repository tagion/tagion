/// Message definitions sent between services
module tagion.services.messages;
import tagion.actor.actor : Msg, Request;

/// Msg Type sent to actors who receive the document
alias inputDoc = Msg!"inputDoc";
/// Msg type sent to receiver task along with a hirpc
alias inputHiRPC = Msg!"inputHiRPC";

/// [FROM: HiRPC Verifier, TO: Collector] Contracts sent to the collector from HiRPC Verifier
alias inputContract = Msg!"contract";

/// [FROM: Epoch Creator, TO: Collector] Contract received from other nodes.
alias consensusContract = Msg!"contract-C";

/// [FROM: Collector, TO: TVM] Verified signed contract with inputs sent to TVM.
alias signedContract = Msg!"contract-S";

/// [FROM: TVM, TO: Transcript] Executed smart contract sent to Transcript.
alias producedContract = Msg!"produced_contract";

/// [FROM: TVM, TO: Epoch Creator] Send new contract into the Epoch Creator
alias Payload = Msg!"Payload";

/// [FROM: Epoch Creator, TO: Transcript] Epoch containing outputs. 
alias consensusEpoch = Msg!"consensus_epoch";

/// [FROM: NodeInterface, TO: Epoch Creator] Receive wavefront from NodeInterface
alias WavefrontReq = Request!"ReceivedWavefront";

/// [TO: Node Interface] send HiRPC to another node 
alias NodeSend = Msg!"node_send";

/// A node action was completed
enum NodeAction {
    sent,
    received,
    dialed,
    accepted,
}

/// An error occurred while doing an aio task
alias NodeError = Msg!"node_error";
alias NNGError = Msg!"nng_error";

/// [FROM: DART, TO: Replicator] Send the produced recorder for replication
alias SendRecorder = Msg!"SendRecorder";
alias readRecorderRR = Request!"readRecorder";
alias syncRecorderRR = Request!"recorderSync";

/// [FROM: DART, TO: TRT] send the recorder to the trt for update
alias trtModify = Msg!"trtModify";

/// [FROM: Transcript, TO: TRT] send the signed contract to the TRT for storing contract
alias trtContract = Msg!"trtContract";

alias trtHiRPCRR = Request!"trtRead"; // trt.dartCRUD: [dartRead, dartCheckRead, dartRim]
alias dartReadRR = Request!"dartRead"; // dartRead Request
alias dartCheckReadRR = Request!("dartCheckRead", immutable(long)); // dartCheckRead Request
alias dartRimRR = Request!"dartRim"; // dartRim Request
alias dartBullseyeRR = Request!"dartBullseye"; // dartBullseye Request
alias dartModifyRR = Request!("dartModify", immutable(long)); // dartModify Request
alias dartFutureEyeRR = Request!("dartFutureEye", immutable(long)); // dartFuture eye request
alias dartHiRPCRR = Request!"dartHiRPCRequest"; // dartCRUD HiRPC commands: [dartRead, dartCheckRead, dartRim]
alias dartCompareRR = Request!"dartCompare";
alias dartSyncRR = Request!"dartSync";
alias dartReplayRR = Request!"dartReplay";

alias EpochShutdown = Msg!"epoch_shutdown"; // Tell the transcript to stop at a specific epoch
