# Task Pool

## In Progress


### Hashgraph viewer
Description: Be able in frontend via query parameter or other in order to specify tagionshell url for websocket that it should connect to.

Assignee: yr

### Logging of events in android
Description: Open a file with the `WalletWrapperSdk path()` function which can be printed to the log in flutter later.
[] - Create DEBUG_ANDROID flag instead of WRITE_LOGS
[] - Check if debug symbols on android libmobile. Are they compiled in?

Assignee: ab

### Hashgraph Consensus bug week 2
Description: After very many epochs a consensus bug is incurred where the epochs are not the same. One node gets behind and seems to stop communcating for a period of time.

- [] Create callback array and reassign pointer on fiber switch
- [] Show all errors for multi-view
- [] profit?

### Hashgraph monitor updates
Tasks: 
- [] Remove old events that are older than X round received. 
- [] Document the hashgraph monitor widget. `docs/docs/gui-tools/hashgraph_viewer.md` 
Assignee: yr

### Wasmer execution engine prototype
Description: Integrate Wasmer as a simple execution engine for WASM smart contracts

Setup the build flow for libwasmer

Implement the interface from D to C of libwasmer.

Initial TVM cli tool.

Assignee: cbr

### Implement "not" flag in HiREP

Description:
The not flag should implement similar function as the `grep -v` or like the `find . -not ...`.
This it should filter out all which matches the pattern.

Assignee: ib


### Contract storage behaviour test
Description: 

DONE
Scenario: Proper contract
* Given a network
* Given a correctly signed contract
* When the contract is sent to the network and goes through
* Then the contract should be saved in the TRT 

WIP
Scenario: Invalid contract
* Given a network
* Given a incorrect contract which fails in the Transcript
* When the contract is sent to the network 
* Then it should be rejected
* Then the contract should not be stored in the TRT

[] - Add function in SecureWallet.d which takes contract and produces hirpc for trt.dartRead of the contract hash.
[] - Check functions should show the amount and expected amount on error.

Labels: [Tracing, TRT]

Assignee: ib

## Backlog

### Envelope on shell
Description: The shell should be able to accept a envelope package.

[] - Create function in CLI-wallet to serialize to envelope.
[] - Shell to deserialize to HiRPC hibon based on if it receives an Envelope

Assignee: yr

### NNG test flow
Description: Extend the CI-pipeline for github.com/tagion/nng to automatically build and execute tests

Assignee: yr

### Subscription API implementation
Description: Provide external API for subscribing and querying data in the system as in [Subscription API proposal](https://docs.tagion.org/tips/3)
Labels: [Tracing]

### Envelope communication
Description: 

Create functionalitiy in wallet to serialize to Envelope.

Create functionality for shell to accept Envelope.

### Mirror Node proposal
Description: Create Query nodes which can be used for both sending and receiving information from the DART.


### HiBON Document max-size check test 
We should make sure that we have check for max-size/out-of-memory
For all external Documents
Like the inputvalidator...

Test should also be made for NNG buffer overrun!

### Impklement wavefront for nodeinterface
description: nodes should be able to communicate p2p on a half-duplex communication using the wavefront protocol
Assignee: lr

### Daily operational test
description: Add a github ci script which activates the operational test once a day
Assignee: lr

## Done

### Hashgraph Consensus bug week 1
Description: After very many epochs a consensus bug is incurred where the epochs are not the same. One node gets behind and seems to stop communcating for a period of time.
Tasks:
- [X] Create fiber test that is deterministic.
- [X] Create weighted random in order to get the failure earlier
- [X] Create multi-hashgraph viewer
- [X] Show error code for the hashgraph that gets the epoch list
- [X] Ifthrown stuff
Assignee: phr

### Mode1 bdd test
Description: Create a test for mode1 which can run in aceptance stage

Tasks:
- [x] Create a testbench program which will run the nodes in different processes.
- [x] Add a check that all nodes produce epochs
- [x] Add the test to acceptance stage

Assignee: lr

### Contract storage / tracing in TRT
Description: We want to save signed contracts going through Transcript service. These contracts should be saved in TRT, but we need to add another type of trt archive. When these contracts are saved in TRT, we can be be notified using subscription on TRT events

Labels: [Tracing, TRT]

Assignee: ib
### Websocket Hashgraph monitor
Description: Websocket hashgraph viewer with NNG websocket using EventView as package object
Note: Changes requested: https://github.com/tagion/tagion/pull/418#pullrequestreview-1959941864

Labels: [Tracing]

Assignee: Yuriy

### Clean up graphview mess
Description: Refactor new svg graphview stuff
Assignee: phr

### Make-flow use dmd -I
Description: Use dmd -I since it greatly reduces build times
Assignee: lr

### Collider network ns
Description: 
add an option to collider so each test runs in separate network namespaces. 
So we can run multiple acceptance stage tests on the same machine

Assignee: lr

## Template
### Task Title
Description: Brief description of the task.
- [] This is an
- [X] Example of how a task can be broken down


Assignee: Name.

Labels (optional): [Label 1], [Label 2]

Priority (optional): High/Medium/Low

Due Date: YYYY-MM-DD
