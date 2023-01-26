# Transaction services

This services handles the format and method validation of the [HiPRC](/documents/protocols/hibon/Hash_invariant_Remote_Procedure_Call.md) request and [HiBON](/documents/protocols/hibon/Hash_invariant_Binary_Object_Notation.md) data format. 

The HiRPC contains the contract and data payload for a transaction. 

Input: 

  - The service expect a binary data stream. 
  - Sender: TLS/TCP Service.

Output:

  - A HiRPC request as HiBON Document. 
  - Receiver: [Collector](/documents/architecture/Collector.md) Service.

The responsibilities of the service are:

  - Check the data package comply with size limitation.
  - Deserialise the data to a HiBON document.
  - Checks the HiRPC method is supported.
  - Validates the signature on the HiRPC request.

The acceptance criteria specification can be found in [Transaction_services](/bdd/tagion/testbench/services/Transaction_service.md).

```mermaid
sequenceDiagram
    participant TLS
    participant Transaction
    participant Collector
    TLS->>Transaction: Document
    Transaction->>Collector: HiRPC.Receiver
```
