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
alias ReceivedWavefront = Msg!"ReceivedWavefront";

/// [TO: Node Interface] send HiRPC to another node 
alias NodeSend = Msg!"node_send";
/// [FROM: Node Interface] HiRPC from other node
alias NodeRecv = Msg!"node_recv";
// Basic node aio task completed
alias NodeAIOTask = Msg!"node_aio_task";
/// A Dial task was completed
alias NodeDial = Msg!"node_dial";
/// An accept task was completed
alias NodeAccept = Msg!"node_accept";

/// [FROM: DART, TO: Replicator] Send the produced recorder for replication
alias SendRecorder = Msg!"SendRecorder";

/// [FROM: DART, TO: TRT] send the recorder to the trt for update
alias trtModify = Msg!"trtModify";

/// [FROM: Transcript, TO: TRT] send the signed contract to the TRT for storing contract
alias trtContract = Msg!"trtContract";

alias trtHiRPCRR = Request!"trtRead"; // trt.dartCRUD: [dartRead, dartCheckRead, dartRim]
alias dartReadRR = Request!"dartRead"; // dartRead Request
alias dartCheckReadRR = Request!("dartCheckRead", long); // dartCheckRead Request
alias dartRimRR = Request!"dartRim"; // dartRim Request
alias dartBullseyeRR = Request!"dartBullseye"; // dartBullseye Request
alias dartModifyRR = Request!("dartModify", long); // dartModify Request
alias dartHiRPCRR = Request!"dartHiRPCRequest"; // dartCRUD HiRPC commands: [dartRead, dartCheckRead, dartRim]
