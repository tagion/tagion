# Task Pool

## In Progress

### CLI testing
Description: Create proposal for how to test CLI-tools
[X] Create proposal
[] Create HiREP tests based on documentation

Assignee: ib

### Hashgraph Consensus bug
Description: After very many epochs a consensus bug is incurred where the epochs are not the same. One node gets behind and seems to stop communcating for a period of time.

- [X] Create callback array and reassign pointer on fiber switch
- [] Show all errors for multi-view. (having problems with this)
- [X] Create Event overload (CBR)
- [] Investigate Youngest Son Ancestor impl.
- [] profit?


### Hashgraph monitor updates
Tasks: 
- [X] Remove old events that are older than X round received. 
- [] Document the hashgraph monitor widget. `docs/docs/gui-tools/hashgraph_viewer.md` 
Assignee: yr
### NNG test flow
Description: Extend the CI-pipeline for github.com/tagion/nng to automatically build and execute tests

Assignee: yr

### Tagion API library
- [X]: Create document API
- []: create HiBON api
- []: create wallet api


### Implement wavefront for nodeinterface
description: nodes should be able to communicate p2p on a half-duplex communication using the wavefront protocol

tasks:
    - [x]: make nng_stream aio tasks convenient to use with std.concurrency
    - [x]: associate in/out-comming connections with public keys
    - [ ]: handle breaking waves
    - [ ]: tests, tests, tests...

Assignee: lr

## Backlog

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

### Daily operational test
description: Add a github ci script which activates the operational test once a day
Assignee: lr

## Done
### Hashgraph viewer
Description: Be able in frontend via query parameter or other in order to specify tagionshell url for websocket that it should connect to.

Assignee: yr

### Envelope on shell
Description: The shell should be able to accept a envelope package.

[X] - Create function in CLI-wallet to serialize to envelope.
[X] - Shell to deserialize to HiRPC hibon based on if it receives an Envelope

Assignee: yr
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

DONE
Scenario: Invalid contract
* Given a network
* Given a incorrect contract which fails in the Transcript
* When the contract is sent to the network 
* Then it should be rejected
* Then the contract should not be stored in the TRT

[X] - Add function in SecureWallet.d which takes contract and produces hirpc for trt.dartRead of the contract hash.
[X] - Check functions should show the amount and expected amount on error.

Labels: [Tracing, TRT]

Assignee: ib


### Logging of events in android
Description: Open a file with the `WalletWrapperSdk path()` function which can be printed to the log in flutter later.
[x] - Create DEBUG_ANDROID flag instead of WRITE_LOGS
[x] - Check if debug symbols on android libmobile. Are they compiled in?
Old serialization enabled in android fixed the problem.

Assignee: ab
### Wasmer execution engine prototype
Description: Integrate Wasmer as a simple execution engine for WASM smart contracts

Setup the build flow for libwasmer

Implement the interface from D to C of libwasmer.

Initial TVM cli tool.

Assignee: cbr

## Template
### Task Title
Description: Brief description of the task.
- [] This is an
- [X] Example of how a task can be broken down


Assignee: Name.

Labels (optional): [Label 1], [Label 2]

Priority (optional): High/Medium/Low

Due Date: YYYY-MM-DD

