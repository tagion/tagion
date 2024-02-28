# HiRPC Verifier Service

[tagion.services.hirpc_verifier](https://ddoc.tagion.org/tagion.services.hirpc_verifier)

This service is responsible for receiving contracts, ensuring a valid data format of HiRPC requests and compliance with the HiRPC protocol before it is executed in the system.

It acts as a gate-keeper ensuring compliance before contracts are send to the Collector Service.

Input:  
> - A [HiRPC](https://www.hibon.org/posts/hirpc/).Receiver received from byte package 

Output:  
> - A [HiBON](https://www.hibon.org/posts/hibon/) Document sent to [Collector](/docs/architecture/Collector.md) Service.

The service does the following:

  - Validate the HiRPC request is correct formatted.
  - Validates signature on permissioned HiRPC request. 
  - Ensure the HiRPC request complay with the protocol
  - Sends a HiRPC request to the Collector service.

If one or more of the checks fails an error should be log and contract be dropped.

The acceptance criteria specification can be found in [services/hirpc_verifier](https://github.com/tagion/tagion/tree/master/bdd/tagion/testbench/services/hirpc_verifier.md).

```mermaid
sequenceDiagram
    participant Input Validator 
    participant HiRPC Verifier 
    participant Collector
    Input Validator->>HiRPC Verifier: HiRPC.Receiver
    HiRPC Verifier->>Collector: HiRPC(if no errors)
```
