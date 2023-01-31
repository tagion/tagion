# Replicator Services

This service is responsible for keeping record of the database instructions both to undo, replay and publish the instructions sequentially.

Input:
  -  Recoder(add/delete) from DART services
  -  Request from the NodeInterface

Output:
  -  Recoder(add/delete) to the Node-Interface
  -  Recoder(add/delete) (undo) to the DART services


The acceptance criteria specification process can be found in [Replicator](
/bdd/tagion/testbench/services/Replicator.md)

```mermaid
sequenceDiagram
    participant DART 
    participant Replicator
    participant NodeInterface
    DART ->> Replicator: Recorder(add/delete)
    Replicator -->> DART: Recorder(delete/add) (undo)
    NodeInterface ->> Replicator: Recorder(add/delete)
    Replicator -->> NodeInterface: Recorder(add/delete) 
````




