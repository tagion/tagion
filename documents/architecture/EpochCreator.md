# Epoch Creator Service

This service is responsbile for resolving the Hashgraph and producing a consensus ordered list of events, an Epoch.

Input:
  - A Contract-SC (Signed Consensus) is received from the [TVM](/documents/architecture/TVM.md) Service. 
  - Wavefront packages received from the [Node Interface](/documents/architecture/NodeInterface.md) Service.

Output:
  - Wavefront packages is sent to the [Node Interface](/documents/architecture/NodeInterface.md) Service.
  - Epoch list is sent to the [Transcript services](/documents/architecture/Transcript.md).

The acceptance criteria specification can be found in [Epoch Creator Service](/bdd/tagion/testbench/services/EpochCreator_Service.md)

The diagram below shows the possible information send from and to the Epoch Creator service.


```mermaid
sequenceDiagram
    participant TVM 
    participant Epoch Creator 
    participant Collector
    participant Transcript
    participant Node Interface
    TVM ->> Epoch Creator: Input/Draft Output Archives
    Epoch Creator ->> Collector: Event payload(Contract) 
    Epoch Creator ->> Node Interface: Wavefront package
    Node Interface ->> Epoch Creator: Wavefront package
    Epoch Creator ->> Transcript: Epoch list
```

