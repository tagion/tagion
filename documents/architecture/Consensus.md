# Consensus Service

This services perform the [HashGraph](HashGraph.md) consensus ordering.

Input:
  - Payload form as document (Typical form the TVM).
  - Wavefront packages from the received from the peer to peer.

Output:
  - Wavefront packages send to a selected node in peer to peer network.
  - Epoch package send to the Transcript services.

The acceptance criteria specification can be found in [Consensus Service](
bdd/tagion/testbench/services/Consensus_Service.md)

The diagram below shows the possible information send from and to the Consensus services.


```mermaid
sequenceDiagram
    participant TVM 
    participant Consensus 
    participant Collector
    participant Transcript
    participant P2P
    TVM ->> Consensus: Input/Output Archives
    Consensus ->> Collector: Event payload(Contract) 
    Consensus ->> P2P: Wavefront package
    P2P ->> Consensus: Wavefront package
    Consensus ->> Transcript: Epoch list
```

