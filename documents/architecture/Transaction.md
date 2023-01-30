# Transaction Service


The service is responsible for ensuring a valid data format of HiRPC requests and HiBON document before it is executed in the system. 

The HiRPC contains the contract and data payload for a transaction. 

Input: 

  - A [HiPRC](/documents/protocols/hibon/Hash_invariant_Remote_Procedure_Call.md).Receiver request.
  - Sender: TLS/TCP Service.

Output:

  - A [HiBON](/documents/protocols/hibon/Hash_invariant_Binary_Object_Notation.md) Document. 
  - Receiver: [Collector](/documents/architecture/Collector.md) Service.

The service does the following:

  - Check the data package comply with size limitation.
  - Validate the HiBON document and HiRPC request are correct formatted.
  - Validates signature on permissioned HiRPC request. 
  - Sends a HiRPC.Reciever request to the Collector service.

The acceptance criteria specification can be found in [Transaction_services](/bdd/tagion/testbench/services/Transaction_service.md).

```mermaid
sequenceDiagram
    participant TLS
    participant Transaction
    participant Collector
    TLS->>Transaction: Document
    Transaction->>Collector: HiRPC.Receiver
```

