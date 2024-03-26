# Task Pool

## In Progress

### Clean up graphview mess
### Hashgraph Consensus bug
Description: After very many epochs a consensus bug is incurred where the epochs are not the same. One node gets behind and seems to stop communcating for a period of time.

Assignee: Philip

### Websocket Hashgraph monitor
Description: Websocket hashgraph viewer with NNG websocket using EventView as package object
Note: Changes requested: https://github.com/tagion/tagion/pull/418#pullrequestreview-1959941864

Labels: [Tracing]

Assignee: Yuriy

### Wasmer execution engine prototype
Description: Integrate Wasmer as a simple execution engine for WASM smart contracts

Assignee: Carsten

### Contract storage / tracing in TRT
Description: We want to save signed contracts going through Transcript service. These contracts should be saved in TRT, but we need to add another type of trt archive. When these contracts are saved in TRT, we can be be notified using subscription on TRT events

Labels: [Tracing, TRT]

Assignee: Ivan 

### Contract storage behaviour test
Description: 

Scenario: Proper contract
* Given a network
* Given a correctly signed contract
* When the contract is sent to the network and goes through
* Then the contract should be saved in the TRT 

Scenario: Invalid contract
* Given a network
* Given a incorrect contract which fails in the Transcript
* When the contract is sent to the network 
* Then it should be rejected
* Then the contract should not be stored in the TRT

Labels: [Tracing, TRT]

Assignee: Ivan

### Mode1 bdd test
Description: Create a test for mode1 which can run in aceptance stage

Tasks:
- [x] Create a testbench program which will run the nodes in different processes.
- [ ] Add a check that all nodes produce epochs
- [ ] Add the test to acceptance stage

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

### Implement "not" flag in HiREP

## Done


## Template
### Task Title
Description: Brief description of the task.
- [] This is an
- [X] Example of how a task can be broken down


Assignee: Name.

Labels (optional): [Label 1], [Label 2]

Priority (optional): High/Medium/Low

Due Date: YYYY-MM-DD
