# Task Pool

## In Progress

### Misc

### C-api fixes
- [ ] check error text is set
- [ ] check rt_init exported functions on android
- [ ] add hibon override/delete key functions

Assignee: lr

## merge wavefront
Assignee: lr, cbr

### Hashgraph Consensus bug
Description: After very many epochs a consensus bug is incurred where the epochs are not the same. One node gets behind and seems to stop communcating for a period of time.

- [X] Create callback array and reassign pointer on fiber switch
- [] Show all errors for multi-view. (having problems with this)
- [X] Create Event overload (CBR)
- [] Investigate Youngest Son Ancestor impl.
- [] profit?

### Wallet 
Description: simplify the wallet logic so that there is only one way to do everything

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

## Backlog

### Distributed nodes test
setup tests for multiple distributed nodes

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

### Types filtering in hirep 
Description: hirep have --types arg, but it's not implemented yet.

- [] - Implement --type filtering in hirep.
- [] - Write bdd test for this feature

---

## Done


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

