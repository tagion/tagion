# Services library

A Tagion Node is divided into units, and each unit handles a service function as follows:

- A smart contract is sent to the **Transaction-service-unit**, fetching the inputs from the **DART unit** and verifying their signatures.
- The **DART unit** connects to other DARTs via the **P2P unit**. The transaction unit forwards the smart contract, including the inputs, to the **Coordinator-unit**, which adds to an event gossiped to the network via the **P2P unit**.
- When the Coordinator receives an event with a smart contract, it is executed via the **ScriptingEngine-unit**, and the result of outputs is verified.
- When the Coordinator finds an epoch, this epoch is forwarded to the **Transcript-service-unit** that evaluates the correct order and requests the **DART-unit** to erase the inputs and add the newly generated outputs.

The Tagion Node service structure:
![](https://hackmd.io/_uploads/Hy3ona4dF.png)
Each of the services is running as independent tasks and communication via commutation channels. The different services modules perform the service as described in the list below.

## Services

**`P2P `**
This service handles the peer-to-peer communication protocol used to communicate between the nodes.

**`Transaction`**
This service receives the incoming transaction script, validates, verifies, and fetches the data from the DART, and sends the information to the Coordinator.
The **`Transaction service`** usees the lib-network to:

- listen to specific port requests like transactions of search in DART;
- receive and execute a contract;
- receive a list of public keys to check if there are any bills in the database;
- send the event with the contract to all network nodes to reach a consensus and make an [epoch](https://github.com/tagion/space-content/blob/master/website-home/Tagion%20Technical%20Paper/hashgraph-consensus-mechanism.md).

**`Coordinator`**
This service manages the hashgraph-consensus and controls another related service for the node. The **`Coordinator`** generates and receives events and relays to the network. This service generates the epoch and sends the information to the **`ScriptingEngine services`**.

**`DART`**
Services to the Distributed database.
The **`ScriptingEngine`** - handles the executions of the scripts.
The **`transcript service`** (internal) is used for creating the [epoch](https://github.com/tagion/space-content/blob/master/website-home/Tagion%) with the recorder for DART inside, and for ordering of the script executuin.
An epoch is a structure containing a recorder and the epoch number and means that the node has reached a consensus according to this data recorder.
When the **`transcript service`** gets this epoch, it checks all the data in this recorder whether they can be added and whether they are not added or deleted twice, for example. If the data checking is correct, the service sends a request to the **`DARTService`**.
The **`DARTSynchronizeServise`** contains a database object and performs all the operations like the data modifying according to the request sent (add, delete, return the DART data by the appropriate hash).

**`Logger`**
The service handles the information logging for the different services.

**`Monitor`**
The Monitor service is used to monitor the activities locally.

**`HeartBeat`**
This service is only used in test mode. This service enables the nodes to execute sequentially, simplifying network debugging.

### Services used depending on the mode started

- **Internal** - `MdnsDiscoveryService` - scans the local network to find nodes.
- **Local** - `FileDiscoveryService` - the path to one file where all nodes should communicate their addresses, and through some delay, all nodes will read all list of addresses.
- **Public** - `ServerFileDiscoveryService` - (similar to the`FileDiscoveryService`) sends data to Tagion shared server.
- **DART synchronization** uses the `DARTSynchronizeService` and has the following stages:

1. the network nodes search before the local node starts and becomes online;
2. connection to different network nodes, and synchronization the missing data to receive some actual DART state;
3. Get online and start the hashgraph.
