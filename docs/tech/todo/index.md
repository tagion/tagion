# Task Pool

## In Progress

### Wallet 
Description: simplify the wallet interface so that there is only one way to do everything


### Epoch Voting
- [X] Test asynchronity of the hashgraph by the amount of nodes
- [ ] Integration test
- [ ] Longitudinal test (Mode 1)


### DART Synchonization services
- [ ] Synchronize a static remote DART to a local DART
- [ ] Synchronize a more static DART's with the same data to one local DART
- [ ] Subscribe to a recorder from one trusted noded.
- [ ] Iterate until until the DART has been synchronize to the common bullseye 
Assignee: al

### TVM CLI
- [X] Simple instructions (WASM)
- [ ] Block jump instructions.
- [ ] Memory instructions.
Assignee: cbr


## Planned in Q1-25

### Hashgraph node swapping
Description: Enable a new node to join the graph
- [ ] Enable a node to follow the graph and build the consensus with out participating
- [ ] Detection when the join node can join the network
- [ ] Implement consensus joining
- [ ] Join the active node epoch generation
Assignee: cbr

### Network Name record
- [ ] Connect the nodes via the Name records.
- [ ] Change the node connection information.
Assignee: lr

### Distributed nodes test
Setup tests for multiple distributed nodes
- [ ] Setup tool to start distribute test network
- [ ] Implement a remote monitor tool for the distribute network
Assignee: lr

### Tauon library for rules contract
Implement the initial library for the contract rules.

### Update the DART-hash function to BLAKE3.

## Backlog

### Hashgraph monitor updates
Tasks: 
- [X] Remove old events that are older than X round received. 
- [ ] Document the hashgraph monitor widget. `docs/tech/gui-tools/hashgraph_viewer.md` 
Assignee: yr

### Add background task to the collider
Collider should be extended to be able to start background process.
- [ ] Add timeout to the test task.
- [ ] Add task dependency between the tasks.
- [ ] Add backout task which can be used by other tests.
Assignee: cr 

### Dump of epoch 
Implement a switch in tagionwave to enable trace dump of the wavefront.

### NNG BDD 
Move the NNG-test to the collider BDD test-frame work
- [ ] The current test program will be executed directly via a bdd test
Assignee: yr

### God-contract
Setup contract which can directly delete and write to the database 
This function will be used in the testnet only. 
- [ ] Implement a contract which can call a dartModify on the DART
Assignee: cr 

### Logger topics
Logger topics enable switch (Remote).


### Tauon was test build fails
Description: Linking of wasm tauon test file fails after 91fd2e09c560530a8ffd19292e82dedc1b5e2d08 or 4999f813071e64f8eda78e98e3b649958f5b52bf because of missing _start function. I've tried reverting both commits individually but it didn't change anything. Also they both seem unrelated.

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
Description: We should make sure that we have check for max-size/out-of-memory
For all external Documents
Like the inputvalidator...


### Daily operational test
Description: Add a github ci script which activates the operational test once a day
Assignee: lr

### Types filtering in hirep
Description: hirep have --types arg, but it's not implemented yet.
- [ ] - Implement --type filtering in hirep.
- [ ] - Write bdd test for this feature

# Update recorderchain documentation
Description: the current recorderchain tool documentation is for a previous version of the tool

### Telegram wavefront
Logger checker via Telegram.

---

## Done

### Gitlab ci trigger
Make a script to trigger the gitlab app ci when the native mobile libraries have been built
Assignee: lr

### DART dry run function
A function which calculates the bullseye on a recorder 
- [X] Implement in a unittest
Assignee: pr

### Tagion API library
- [X] Create document API
- [x] create HiBON api
- [x] create wallet api

### Hashgraph Consensus bug
Description: After very many epochs a consensus bug is incurred where the epochs are not the same. One node gets behind and seems to stop communcating for a period of time.

- [X] Create callback array and reassign pointer on fiber switch
- [X] Show all errors for multi-view. (having problems with this)
- [X] Create Event overload (CBR)

### NNG test flow
Description: Extend the CI-pipeline for github.com/tagion/nng to automatically build and execute tests
Assignee: yr

### Fix Mode1 test
Description: Mode1 test doesn't work with other than 5 nodes
Assignee: lr

### C-api fixes
- [x] check error text is set
~- [ ] check rt_init exported functions on android~ This is insignifant and we decided not to spend time on this now. Currently just use start_rt
- [x] add hibon override/delete key functions
Assignee: lr

## Merge wavefront
Description: Merge the changes to the hashgraph with changes to the wavefront and ensure that all tests pass.
Assignee: lr, cbr

---

## Template
### Task Title
Description: Brief description of the task.
- [] This is an
- [X] Example of how a task can be broken down


Assignee: Name.

Labels (optional): [Label 1], [Label 2]

Priority (optional): High/Medium/Low

Due Date: YYYY-MM-DD
