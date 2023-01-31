# Consensus Interface Services

This services takes care of the P2P network interface used for the general network correction and the
Gossip protocol.

All the package information is in **HiPRC** format.

Input:
  - 

```mermaid
sequenceDiagram
    participant Replicator 
    participant DARTSync 
    participant ConsensusInterface 
    DARTSync ->> DART: DART(crud)
    ConsensusInterface ->> DARTSync: DART(ro)
    DARTSync ->> ConsensusInterface: DART(ro)
    Replicator ->> DARTSync: Recorder
```


