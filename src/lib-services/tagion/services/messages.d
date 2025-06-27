/// Message definitions sent between services
module tagion.services.messages;
import tagion.actor.actor : Msg, Request;

/// [FROM: rpcserver, TO: HiRPCVerifier] HiRPC Document
alias inputDoc = Msg!"inputDoc";

/// [FROM: HiRPCVerifier, TO: Collector] Signed hirpc
alias inputHiRPC = Msg!"inputHiRPC";


/**
[FROM: Epoch Creator, TO: Collector]
[FROM: Collector, TO: TVM]
Contracts that have gone through consensus
 */
alias consensusContract = Msg!"contract-C";

/// [FROM: Collector, TO: TVM] Verified signed contract with inputs sent to TVM.
alias signedContract = Msg!"contract-S";

/// [FROM: TVM, TO: Transcript] Executed smart contract sent to Transcript.
alias producedContract = Msg!"produced_contract";

/// [FROM: TVM, TO: Epoch Creator] Send new contract into the Epoch Creator
alias Payload = Msg!"Payload";

/// [FROM: Epoch Creator, TO: Transcript] Epoch containing outputs. 
alias consensusEpoch = Msg!"consensus_epoch";

/// [FROM: Supervisor, TO: transcript] Tell the transcript to stop at a specific epoch
alias EpochShutdown = Msg!"epoch_shutdown";

/// [FROM: Transcript, TO: EpochCommit] Sent when finalizing an epoch
alias EpochCommitRR = Request!("EpochCommit", immutable(long));

/// [FROM: NodeInterface, TO: Epoch Creator] Receive wavefront from NodeInterface
alias WavefrontReq = Request!"ReceivedWavefront";

/// [TO: Node Interface] send HiRPC to another node 
alias NodeSend = Request!"node_send";

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
alias NodeReq = Request!"node_req";

/// [FROM: EpochCommit, TO: Replicator] Send the produced recorder for recorderchain
alias Replicate = Request!"ReplicateRecorder";

alias readRecorderRR = Request!"readRecorder";
alias syncRecorderRR = Request!"recorderSync";
alias repHiRPCRR = Request!"replicatorHiRPCRequest";
alias repFilePathRR = Request!"repFilePath";

/// [FROM: EpochCommit, TO: TRT] send the recorder to the trt for update
alias trtModify = Msg!"trtModify";

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
