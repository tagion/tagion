# Communication Service

The service is responsible for ensuring a valid data format of HiRPC requests and ensuring the HiRPC protocol is obeyed. 

It acts as a gate-keeper ensuring compliance before contracts are send to the Collector Service.

Input: 

  - A [HiPRC](/documents/protocols/hibon/Hash_invariant_Remote_Procedure_Call.md).
  - Sender: TLS/TCP Service.

Output:

  - A [HiBON](/documents/protocols/hibon/Hash_invariant_Binary_Object_Notation.md) Document. 
  - Receiver: [Collector](/documents/architecture/Collector.md) Service.

The service does the following:

  - Check the data package comply with size limitation.
  - Validate the HiBON document and HiRPC request are correct formatted.
  - Validates signature on permissioned HiRPC request. 
  - Sends a HiRPC request to the Collector service.

The acceptance criteria specification can be found in [Transaction_services](/bdd/tagion/testbench/services/Transaction_service.md).

```mermaid
sequenceDiagram
    participant TLS
    participant Transaction
    participant Collector
    TLS->>Transaction: Document
    Transaction->>Collector: HiRPC.Receiver
```

