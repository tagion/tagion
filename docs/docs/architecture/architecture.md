# Architecture

## Description of the services in a node
A node consist of the following services.


* [tagionwave](/docs/tools/tagionwave) is the main task responsible all the service
- Main services
	- Supervisor manages all the other services
    - [Input Validator](/docs/architecture/InputValidator.md) This service handle the data-stream input to the network.
    - [HiRPC Verifier](/docs/architecture/HiRPCVerifier.md) service is responsible for receiving contracts, ensuring a valid data format of HiRPC requests and compliance with the HiRPC protocol before it is executed in the system. 
	- [Collector](/docs/architecture/Collector.md) service is responsible for collecting input data for a Contract and ensuring the data is valid and signed before the contract is executed by the TVM.
	- [TVM](/docs/architecture/TVM.md) ("Tagion Virtual Machine") is responsible for executing the instructions in the contract ensuring the contracts are compliant with Consensus Rules producing outputs and sending new contracts to the Epoch Creator.
	- [Transcript](/docs/architecture/Transcript.md) service is responsible for producing a Recorder ensuring correct inputs and output archives including no double input and output in the same Epoch and sending it to the DART.
	- [Epoch Creator](/docs/architecture/EpochCreator.md) service is responsible for resolving the Hashgraph and producing a consensus ordered list of events, an Epoch. 
	- [DART](/docs/architecture/DART.md "Distributed Archive of Random Transactions") service is responsible for executing data-base instruction and read/write to the physical file system.
	- [DART Interface](/docs/architecture/DartInterface.md) handles outside read requests to the dart
    - [TRT](/docs/architecture/TRT.md) "Transaction reverse table" stores a copy of the owner to bill relationship.
	- [Replicator](/docs/architecture/Replicator.md) service is responsible for keeping record of the database instructions both to undo, replay and publish the instructions sequantially.
	- [Node Interface](/docs/architecture/NodeInterface.md) service is responsible for handling and routing requests to and from the p2p node network.

* Support services
	- [Logger](/docs/architecture/Logger.md) takes care of handling the logger information for all the services.
	- [Logger Subscription](/docs/architecture/LoggerSubscription.md) The logger subscript take care of handling remote logger and event logging.
	- [Monitor](/docs/architecture/Monitor.md) Monitor interface to display the state of the HashGraph.

## Connection types
By default all of these sockets are private, ie. they are linux abstract sockets and can only by accessed on the same machine.
The socket address, and thereby the visibility can be changed in the tagionwave config file.


| [Input Validator](/docs/architecture/InputValidator.md) | [Dart Interface](/docs/architecture/DartInterface.md) | [Subscription](/docs/architecture/LoggerSubscription.md) | [Node Interface](/docs/architecture/NodeInterface.md) |
| -                                                            | -                                                          | -                                                             | -                                                          |
| Write                                                        | Read-only                                                  | Pub                                                           | Half-duplex p2p wavefront communication                    |
| **HiRPC methods**                                            | ..                                                         | ..                                                            | ..                                                         |
| "submit"                                                     | "search"                                                   | "log"                                                         |
|                                                              | "dartCheckRead"                                            |
|                                                              | "dartRead"                                                 |
|                                                              | "dartRim"                                                  |
|                                                              | "dartBullseye"                                             |
| **NNG Socket type**                                          | ..                                                         | ..                                                            | ..                                                         |
| REPLY                                                        | REPLY                                                      | PUBLISH                                                       | ???                                                        |


## Data Message flow
This graph show the primary data message flow in the node.

![Node data flow](/figs/node_dataflow.excalidraw.svg)

## Tagion Service Hierarchy

This graph show the supervisor hierarchy of the services in the network.

The arrow indicates ownership is means of service-A points to service-B. Service-A has ownership of service-B.

This means that if Service-B fails service-A is responsible to handle and take-care of the action to restart or other action.

```mermaid
flowchart TD
    Input(Input Validator)
    Tagionwave --> Logger
    Logger --> LoggerSubscription
    Tagionwave --> Supervisor
    Supervisor --> NodeInterface
    NodeInterface --> P2P
    Supervisor --> DART
    DART --> Replicator
    Supervisor --> Collector
    Collector --> TVM
    Collector --> EpochCreator
    EpochCreator --> Transcript
    Transcript --> EpochDump
    EpochCreator --> Monitor
    Collector --> HiRPCVerifier
    HiRPCVerifier --> Input
```
