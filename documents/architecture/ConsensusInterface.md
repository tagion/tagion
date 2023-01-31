# Consensus Interface Services

This services takes care of the P2P network interface used for the general network correction and the
Gossip protocol.

All the package information is in **HiPRC** format.

Input:
  - 

```mermaid
sequenceDiagram
    participant Replicator 
    participant DARTInterface 
    participant ConsensusInterface 
    DARTInterface ->> DART: DART(crud)
    ConsensusInterface ->> DARTInterface: DART(ro)
    DARTInterface ->> ConsensusInterface: DART(ro)
    Replicator ->> DARTInterface: Recorder
```


