# Task Pool

## In Progress

### DART Synchronization services (mode2) 
Description: Function to allow a program to remotely synchronize a dart from a node  
Goal: May  
- [x] Synchronize a static remote DART to a local DART
- [x] Synchronize more static DART's with the same data to one local DART
- [x] Subscribe to a recorder from one trusted node.
- [x] Iterate until until the DART has been synchronize to the common bullseye  
Assignee: al  


### Graph Mirroring (mode2) 
Description: create a function can get all new events using wavefront and create a non voting graph of the events
Goal: May  
Enable a new node to join the graph  
- [x] Enable a node to follow the graph and build the consensus with out participating
- [x] Add graph witness fingerprints to the DART
- [ ] Bootstrap the graph with the witness events from the dart
- [ ] Create a test that the events are properly mirrored and voted  
Assignee: lr  


### Network Catchup (mode2) 
Goal: May  
- [x] depends on: DART Synchronization services
- [ ] depends on: Graph Mirroring
- [ ] integrate in tagionwave, start the network and sync until it can join the network
      when the node starts it should detect that it is out of sync and start mirroring the graph and syncing the dart
- [ ] bdd which checks that a node can catch up and switch from offline to online   
Assignee: lr, al


### TVM Util
Description: A tool which can execute a contract with wasm instructions against a local DART  
Goal: May  
- [X] Simple instructions (WASM)
- [ ] Block jump instructions.
- [ ] Memory instructions.  
Assignee: cbr  


### TIP6
Description: docs.tagion.org/tips/6  
Goal: May  
- [ ] add hash of executed contract to recorderchain
- [ ] add hash of recorderblock to epochchain  
Assignee: lr  

### Seperate hashnet and securenet
Description: prepare to be able to use alternate hashing algorithm (ie. blake3)  
- [x] Make hashnet and securenet seperate classes  
Assignee: cbr

-----------------------------------------------------------------------------------------

## Backlog

### Network Joining and participation (Mode2)
Goal: Q3  
- [ ] make sure that the newly joined nodes can add events to the graph
- [ ] detect that the nodes votes is a part of deciding witnesses
- [ ] when this is detected allow the node to update the database (producing epochs)

### Shell Cleanup
Goal: Q2  
- [ ] Fix memory leak
- [ ] Move everything that is not related a part of the core functionality to a seperate module (forwarding rpc, caching)
- [ ] Find out why request often end in htp 405,503,502,504  

### Deployment testing
Goal: May  
- [ ] Backup the production dart to an external
- [ ] Test if the production network can run on the current code for 4 weeks in mode0

### Distributed testing
Description: We want the infrastruct to be able to test new version of the network in a distributed manner  
Goal: Q2  
- [ ] Create a service were peope can associate their public key with a machine
- [ ] Create a tool were we can assign specific docker images to a group of public keys and assigne network boot data to that group
- [ ] Create a deployment/tutorial were people can setup a node and automatically updates to newly assigned images.  

### TVM Service
Goal: Q2
- [ ] Add wasm execute to tvm service
- [ ] The tvm service should execute wasm script that are loaded from the dart.
- [ ] The entrypoint function `run()`? should always take the inputs, reads and outputs  
Assignee: cbr  

### Epoch MuSig:
Description:  
Goal: Q3  
- [/] implement Schnoor MuSig
- [ ] Make sure that multi user signatures don't leak private keys.
- [ ] Replace signatures in epoch chain with aggregated MuSig  
Assignee: cbr  

### DART Blake3
Goal: Q2  
- [ ] Write a TIP proposal for how to migrate and explaining the motivation
- [ ] add blake3 hashing algorithm
- [ ] create a translation table for old dartreads  

### Protocol violations
- [ ] Add proper error handling for nodeinterface when the response is larger than the allowed
- [ ] Limit the request response size from the wavefront  

### Logger topics
- [ ] Be able to toggle the event logger topics without restarting tagionwave.

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

### HiBON Document max-size check test 
Description: We should make sure that we have check for max-size/out-of-memory
For all external Documents
Like the inputvalidator...  

# Update recorderchain documentation
Description: the current recorderchain tool documentation is for a previous version of the tool
- [ ] Add documentation for how to use the new tool
- [ ] Pick one tool, either kette or vergangenheit and make sure there is feature parity  

-----------------------------------------------------------------------------------------

## Done

### Hashgraph monitor updates
- [X] Remove old events that are older than X round received. 
- [x] Document the hashgraph monitor widget. `docs/tech/gui-tools/hashgraph_viewer.md`  
Assignee: yr  

### Add background task to the collider
Collider should be extended to be able to start background process.
- [x] Add timeout to the test task.
- [x] Add task dependency between the tasks.
- [ ] ~Add backout task which can be used by other tests.~  
Assignee: cr  

### Telegram wavefront
- [x] Logger checker via ~Telegram.~ slack  

### Network Name record
- [x] Connect the nodes via the Name records.  
Assignee: lr  

### NNG BDD 
Description: Move the NNG-test to the collider BDD test-frame work  
- [x] The current test program will be executed directly via a bdd test  
Assignee: yr  

### Tauon was test build fails
Description: Linking of wasm tauon test file fails after 91fd2e09c560530a8ffd19292e82dedc1b5e2d08 or 4999f813071e64f8eda78e98e3b649958f5b52bf because of missing _start function. 
I've tried reverting both commits individually but it didn't change anything. Also they both seem unrelated.  

### God-contract
Setup contract which can directly delete and write to the database 
This function will be used in the testnet only. 
- [x] Implement a contract which can call a dartModify on the DART  
Assignee: cr  

### Types filtering in hirep
Description: hirep have --types arg, but it's not implemented yet.
- [x] - Implement --type filtering in hirep.
- [x] - Write bdd test for this feature  
Assignee: ib  

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

### Merge wavefront
Description: Merge the changes to the hashgraph with changes to the wavefront and ensure that all tests pass.  
Assignee: lr, cbr
