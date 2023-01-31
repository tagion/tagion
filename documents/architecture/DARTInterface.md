# DARTInterface Services

This services takes care of the remote synchronisation of the DART.

When a node start and after it node has discovered the trusted network. 

Input:
  - **DART(ro)** command from ConsensusInterface.
  - Recorder from the Replicator Services.
  - 

Request:
  - Request **DART(ro)** to the ConsensusInterface.
  - Request **DART(crud)** to the DART.

Output:
  - y


### DART Synchronization start up

```mermaid
sequenceDiagram
    participant DART 
    participant Replicator 
    participant DARTInterface
    participant ConsensusInterface 
    DARTInterface ->> ConsensusInterface: Request last Recorder
    ConsensusInterface --> DARTInterface: Recorder
    loop [list of sectors]
       DARTInterface ->> ConsensusInterface: DART(crud)
       ConsensusInterface ->> DARTInterface: DART(ro)
       DARTInterface --> ConsensusInterface: d
       DARTInterface ->> ConsensusInterface: DART(ro)
    Replicator ->> DARTInterface: Recorder
	end

```

