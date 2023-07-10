# Tagion Network Architecture

## Description of the services in a node
A node consist of the following services.


* [tagionwave](/src/bin-wave/README.md) is the main task responsible all the service
- Main services
	- [Tagion](/documents/architecture/Tagion.md) is the service which handles the all the services related to the rest of the services (And run the HashGraph).
	- [Tagion Factory](/documents/architecture/TagionFactory.md) This services takes care of the *mode* in which the network is started.
    - [Input Validator](/documents/architecture/InputValidator.md) This service handle the data-stream input to the network.
    - [Contract Verifier](/documents/architecture/ContractVerifier.md) service is responsible for receiving contracts, ensuring a valid data format of HiRPC requests and compliance with the HiRPC protocol before it is executed in the system. 
	- [Collector](/documents/architecture/Collector.md) service is responsible for collecting input data for a Contract and ensuring the data is valid and signed before the contract is executed by the TVM.
	- [TVM](/documents/architecture/TVM.md) ("Tagion Virtual Machine") is responsible for executing the instructions in the contract ensuring the contracts are compliant with Consensus Rules producing outputs and sending new contracts to the Epoch Creator.
	- [Transcript](/documents/architecture/Transcript.md) service is responsible for producing a Recorder ensuring correct inputs and output archives including no double input and output in the same Epoch and sending it to the DART.
	- [Epoch Creator](/documents/architecture/EpochCreator.md) service is responsible for resolving the Hashgraph and producing a consensus ordered list of events, an Epoch. 
	- [DART](/documents/architecture/DART.md "Distributed Archive of Random Transactions") service is reponsible for executing data-base instruction and read/write to the physical file system.
	- [Replicator](/documents/architecture/Replicator.md) service is responsible for keeping record of the database instructions both to undo, replay and publish the instructions sequantially.
	- [Node Interface](/documents/architecture/NodeInterface.md) service is responsible for handling and routing requests to and from the p2p node network.

* Support services
	- [Logger](/documents/architecture/Logger.md) takes care of handling the logger information for all the services.
	- [Logger Subscription](/documents/architecture/LoggerSubscription.md) The logger subscript take care of handling remote logger and event logging.
	- [Monitor](/documents/architecture/Monitor.md) Monitor interface to display the state of the HashGraph.
	- [Epoch Dump](/documents/architecture/EpochDump.md) Service is responsible for writing the Epoch to a file as a backup.


## Data Message flow
This graph show the primary data message flow in the network.

```graphviz
digraph Message_flow {
  compound=true;
  labelangle=35;
  node [style=filled]
  node [ shape = "rect"];
  DART [href="#/documents/architecture/DART.md" shape = cylinder];
  Input [href="#/documents/architecture/InputValidator.md" label="Input\nValidator" style=filled fillcolor=green ]
  P2P [ style=filled fillcolor=red]
  ContractVerifier [href="#/documents/architecture/ContractVerifier.md"  label="Contract\nVerifier"]
  NodeInterface [href="#/documents/architecture/NodeInterface.md"  label="Node\nInterface"]
  Transcript [href="#/documents/architecture/Transcript.md" shape = note]
  EpochCreator [href="#/documents/architecture/EpochCreator.md" label="Epoch\nCreator"]
  TVM [href="#/documents/architecture/TVM.md"]
  Collector [href="#/documents/architecture/Collector.md"]
  Replicator [href="#/documents/architecture/Replicator.md"]

  Input -> ContractVerifier [label="HiRPC(contract)" color=green];
  ContractVerifier -> Collector [label="contract-NC" color=green];
  Collector -> TVM [label="contract-S" color=green];
  EpochCreator -> Collector [label="contract-C" color=darkgreen];
  EpochCreator -> Transcript [label=epoch color=green];
  TVM -> Transcript [label="archives\nin/out" color=red];
  TVM -> EpochCreator [label="contract-SC" color=green];
  DART -> Replicator [label=recorder color=red dir=both];
  DART -> NodeInterface [label="DART(ro)\nrecorder" dir=both color=magenta];
  NodeInterface -> P2P [label=Document dir=both];
  DART -> Collector [label="recorder\nin/read" color=red];
  EpochCreator -> NodeInterface [label=wavefront dir=both color=cyan4];
  Transcript -> DART [label=recorder color=blue];
  Replicator -> NodeInterface [label=recorder];
}
```

## Tagion Service Hierarchy

This graph show the supervisor hierarchy of the services in the network.

The arrow indicates ownership is means of service-A points to service-B. Service-A has ownership of service-B.

This means that if Service-B fails service-A is responsible to handle and take-care of the action to restart or other action.


```graphviz
digraph tagion_hierarchy {
    rankdir=UD;
    size="8,5"
   node [style=filled shape=rect]
   Input [href="#/documents/architecture/InputValidator.md" label="Input\nValidator" color=green ]
Tagion [href="#/documents/architecture/Tagion.md"]
Tagionwave [color=blue]
TagionFactory [href="#/documents/architecture/Collector.md" label="Tagion\nFactory"]
TVM [href="#/documents/architecture/TVM.md"] 
DART [href="#/documents/architecture/DART.md" shape = cylinder]
Replicator [href="#/documents/architecture/Replicator.md"] 
ContractVerifier [href="#/documents/architecture/ContractVerifier.md" label="Contract\nVerifier"]
Transcript [href="#/documents/architecture/Transcript.md" shape = note]
Collector [href="#/documents/architecture/Collector.md" shape=rect]
EpochCreator [href="#/documents/architecture/EpochCreator.md" label="Epoch\nCreator"]
EpochDump [href="#/documents/architecture/EpochDump.md" label="Epoch\nDump"]
NodeInterface [href="#/documents/architecture/NodeInterface.md" lshape=rect label="Node\nInterface"]
P2P [href="#/documents/architecture/P2P.md" color=red]
LoggerSubscription [href="#/documents/architecture/LoggerSubscription.md" label="Logger\nSubscription"]
Logger [href="#/documents/architecture/Logger.md"] 
Monitor [href="#/documents/architecture/Monitor.md"] 
node [shape = rect];
	Tagionwave -> Logger -> LoggerSubscription;
	Tagionwave -> TagionFactory;
	TagionFactory -> Tagion;
	Tagion -> NodeInterface -> P2P;
	DART -> Replicator;
	Tagion -> DART;
    Tagion -> EpochCreator;
	EpochCreator -> ContractVerifier;
	EpochCreator -> Transcript;
	EpochCreator -> Collector;
	Transcript -> EpochDump;
	EpochCreator -> Monitor;
	Collector -> TVM;
	ContractVerifier -> Input;
}
```
