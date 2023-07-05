# DART Service
## General structure of the DART modules

```graphviz
digraph module_diagram {
    rankdir="TB"; // Top to Bottom direction
    node [shape="rectangle", fontsize=12, fontname="Helvetica"];
    edge [fontsize=10, fontname="Helvetica"];

    DART -> Dartutil [dir="none", weight=100];
    DART -> DARTFile [dir="none", weight=100];
    DART -> Synchronizer [dir="none", weight=100];
    DARTFile -> BlockFile [dir="none", weight=100];
    BlockFile -> Blockutil [dir="none", weight=100];
    BlockFile -> Recycler [dir="none", weight=100];
    BlockFile -> BlockSegment [dir="none", weight=100];
    Recycler -> RecycleSegment [dir="none", weight=100];
    BlockSegment -> Blocks [dir="none", weight=100];

    {rank=same; DART Dartutil}
    {rank=same; Blockutil Recycler BlockSegment}
    {rank=same; Blocks RecycleSegment}
}
```

# DARTFile structure
![Alt text](../figs/dartstructure.png?raw=true)


## CRUD

This service is reponsible for executing data-base instruction and read/write to the physical file system.

Note.
The DART does not support `update` only `add` and `delete`. 

The DART database support 4 **DART(crud)** commands.
  - `dartBullseye` returns the bullseye (Merkle root) of the DART.
  - `dartRim` reads a list of branch(tree) for a given rim.
  - `dartRead` reads a list of archives from a list of fingerprints.
  - `dartModify` adds and deletes a list of archives form a Recorder.

The `dartModify` should only be executed inside a Node, either from the transcript or when the nodes starts up in the DART sync process.

The read-only dart command **DART(ro)** is defined as `dartBullseye`, `dartRim` and `dartRead`.

All archives in the database has a unique hash-value called fingerprint.

Input:
  - Recorder is received from the [Transcript](/documents/architecture/Transcript.md) Service.
  - Undo-instruction is received from the [Transcript](/documents/architecture/Transcript.md) Service.
  - Recorder rewind is received from the [Replicator](/documents/architecture/Replicator.md) Service.

Request:
  - **DART(ro)** commands from the [Node Interface](/documents/architecture/NodeInterface.md)) Service.

Output:
  - Last Recoder is sent to the [Replicator](/documents/architecture/Replicator.md) Service. 


### DART Start up
When a node goes online the DART needs to be synchronized with other nodes in the network.
Before the DART should be synchronized the node should run trough the discovery of the trusted network (This process is not described here)

The DART database should be synchronized before the DART can be used as a consensus database.

DART start-up flowchart:

```graphviz
digraph G {
  node [fontname = "Handlee"];
  edge [fontname = "Handlee"];

  start [
    label = "Start";
    shape = rect;
  ];
  connect [
    label = "Connect\ntrusted\nnetwork";
    shape = rect;
  ];
  sync [
    label = "Sync\nDART";
    shape = rect;
  ];
  insync [
    label = "Bullseye\nok?";
    shape = diamond;
  ];
  resync [
    label = "Continue\nDART";
    shape = rect;
  ];
   dart [
    label = "DART\nin sync!";
    shape = rect;
  ];

  start -> connect;
  connect -> sync:n;
  sync:s -> insync:n;
  resync:n -> sync:e;
  insync:s -> dart [ label = "Yes" ];
  insync -> resync [ label = "No" ];
  {
    rank=same;
    insync; resync; 
  }
}
```
Note. The synchronization method can be found in DART. SynchronizationFiber which also support HiPRC. 
For sample code see the unittest in the DART module.
DART also includes a journal-files which can be used in case of a crash.

The acceptance criteria specification for the synchronization  process can be found in [DART Sync](
/bdd/tagion/testbench/services/DART_Sync.md)


### DART Operation

When the DART success-fully has reached the current bullseye state then the DART is ready to receive Recorders from the transcript service. That will keep the DART in the consensus state as long as the network produces Epochs and Recorders.

In the case that an Epoch do not have majority voting on the last bullseye, then the Transcript Service sends a DART undo command to the DART services. This means that the previous Recorder must be undo and this is done by requesting the Recorder from the Replicator and the Recorder is reversed by the `dartModify` command. 
The bullseye after the Recorder has been executed is written into the next Epoch to ensure the consensus state of the database. In other words, a database state is first final in the next consensus round if all the network participants have agreed on the state. That is the last valid consensus database state, consensus bullseye, in the network.


The acceptance criteria specification can be found in [DART Service](
/bdd/tagion/testbench/services/DART_Service.md)


```mermaid
sequenceDiagram
    participant Collector
    participant Transcript
    participant DART 
    participant Replicator
    Transcript ->> DART: Recorder(add/delete)
    DART ->> Replicator: Recorder(add/delete)
    Transcript ->> DART: Request undo
    Replicator -->> DART: Recorder(delete/add) (undo)
    Collector ->> DART: dartRead
    DART -->> Collector: Recorder(read)
```

The Recorder protocol can be found in [Recorder](documents/protocols/dart/Recorder.md)
```mermaid
stateDiagram-v2
[*] --> Still
Still --> [*]
Still --> Moving
Moving --> Still
Moving --> Crash
Crash --> [*]
```

