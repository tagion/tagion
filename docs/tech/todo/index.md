# Task Pool

## In Progress

### Wallet 
Description: simplify the wallet interface so that there is only one way to do everything

### Epoch Voting
- [X] Test asynchronity of the hashgraph by the amount of nodes
- [ ] Integration test
- [ ] Longitudinal test (Mode 1)

### DART Synchronization services
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

## Planned in Q2-25
mode2:
    network joining service
    priority: 1
        - dart sync
            create a function to allow a program to remotely synchronize the dart from a node
        - graph-mirror
            create a function can get all new events using wavefront and create a non voting graph of the events
        - integrate in tagionwave, start the network and sync until it can join the network
            when the node starts it should detect that it is out of sync and start mirroring the graph and syncing the dart
        - bdd which checks that a node can catch up and switch from offline to online
    active participation
    priority: 2
        - make sure that the newly joined nodes can add events to the graph
        - detect that the nodes votes is a part of deciding witnesses
        - when this is detected allow the node to update the database (producing epochs)


tvm:
    priority 1a:
        - tvmutil
            should be able execute wasm against a dart
    priority 2a:
        - add wasm execute to tvm service
            the tvm should execute wasm script that are loaded from the dart.
            the entrypoint function `run()`? should always take the inputs, reads and outputs
    priority 3a:
        - update tauon library
            update the existing functions in libcapi


testing setup:
    priority 1:
    - test if the production network can run on the current code for 4 weeks in mode0
    priority 2b:
    distributed test setup:
        - create a service were peope can associate their public key with a machine
        - create a tool were we can assign specific docker images to a group of public keys and assigne network boot data to that group
        - create a deployment/tutorial were people can setup a node and automatically updates to newly assigned images.


tip6:
    priority 1c:
    docs.tagion.org/tips/6
    - add hash of executed contract to recorderchain
    - add hash of recorderblock to epochchain
    merkle proofs and hash trie compression is addon for later


blake3:
    - create a tip for converting
    - add blake3 hashing algorithm
    - create a translation table for old dartreads


multisig:
    - implement schnoor multisig
    - make sure that multi user signatures don't leak private keys
        create a unique bitvector for each signing
    - add multisig signatures to epoch chain


## Planned in Q1-25

### Hashgraph node swapping
Description: Enable a new node to join the graph
- [x] Enable a node to follow the graph and build the consensus with out participating
- [ ] Detection when the join node can join the network
- [ ] Implement consensus joining
- [ ] Join the active node epoch generation
Assignee: cbr

### Network Name record
- [x] Connect the nodes via the Name records.
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

### Protocol violations
- [ ] Add proper error handling for nodeinterface when the response is larger than the allowed
- [ ] Limit the request response size from the wavefront

### Hashgraph monitor updates
Tasks: 
- [X] Remove old events that are older than X round received. 
- [ ] Document the hashgraph monitor widget. `docs/tech/gui-tools/hashgraph_viewer.md` 
Assignee: yr

### Add background task to the collider
Collider should be extended to be able to start background process.
- [x] Add timeout to the test task.
- [x] Add task dependency between the tasks.
- [ ] Add backout task which can be used by other tests.
Assignee: cr 

### Dump of epoch 
Implement a switch in tagionwave to enable trace dump of the wavefront.

### Logger topics
Logger topics enable switch (Remote).

### Subscription API implementation
Description: Provide external API for subscribing and querying data in the system as in [Subscription API proposal](https://docs.tagion.org/tips/3)
Labels: [Tracing]

### Envelope communication
- [ ]: Discuss Envelope spec. 
        Current spec is not compatible tagion.crypto.Cipher.
        Does it really need a length field when hibon already has one.
        Encodes compression level but this is already encoded in zlib header
- [ ]: Create functionalitiy in wallet to serialize to Envelope.
- [ ]: Create functionality for shell to accept Envelope.

### Mirror Node proposal
Description: Create Query nodes which can be used for both sending and receiving information from the DART.

### HiBON Document max-size check test 
Description: We should make sure that we have check for max-size/out-of-memory
For all external Documents
Like the inputvalidator...

# Update recorderchain documentation
Description: the current recorderchain tool documentation is for a previous version of the tool
- [ ] Add documentation for how to use the new tool
- [ ] Pick one tool, either kette or vergangenheit and make sure there is feature parity

### Telegram wavefront
Logger checker via Telegram.

---

## Done

### NNG BDD 
Move the NNG-test to the collider BDD test-frame work
- [x] The current test program will be executed directly via a bdd test
Assignee: yr

### Tauon was test build fails
Description: Linking of wasm tauon test file fails after 91fd2e09c560530a8ffd19292e82dedc1b5e2d08 or 4999f813071e64f8eda78e98e3b649958f5b52bf because of missing _start function. I've tried reverting both commits individually but it didn't change anything. Also they both seem unrelated.

### God-contract
Setup contract which can directly delete and write to the database 
This function will be used in the testnet only. 
- [x] Implement a contract which can call a dartModify on the DART
Assignee: cr 

### Types filtering in hirep
Description: hirep have --types arg, but it's not implemented yet.
- [x] - Implement --type filtering in hirep.
- [x] - Write bdd test for this feature


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
