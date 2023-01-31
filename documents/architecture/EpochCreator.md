# Epoch Creator Service

This service is responsbile for resolving the Hashgraph and producing a consensus ordered list of events, an Epoch.

Input:
  - A Contract-SC (Signed Consensus) is received from the [TVM](/documents/architecture/TVM.md) Service. 
  - Wavefront packages received from the [P2P]() Service.

Output:
  - Wavefront packages is sent to the [P2P]() Service.
  - Epoch list is sent to the [Transcript services](/documents/architecture/Transcript.md).

The acceptance criteria specification can be found in [Epoch Creator Service](
/bdd/tagion/testbench/services/EpochCreator_Service.md)

The diagram below shows the possible information send from and to the Consensus services.


```mermaid
sequenceDiagram
    participant TVM 
    participant Epoch Creator 
    participant Collector
    participant Transcript
    participant Consensus Interface
    TVM ->> Epoch Creator: Input/Output Archives
    Consensus ->> Collector: Event payload(Contract) 
    Consensus ->> Consensus Interface: Wavefront package
    Consensus Interface ->> Epoch Creator: Wavefront package
    Consensus ->> Transcript: Epoch list
```

