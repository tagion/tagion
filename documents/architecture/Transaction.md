# Transaction services

This services handles the format and method validation of the [HiPRC](/documents/protocols/hibon/Hash_invariant_Remote_Procedure_Call.md). request and [HiBON](/documents/protocols/hibon/Hash_invariant_Binary_Object_Notation.md) data format. 

The HiRPC contains the contract and data payload for a transaction. 

Input interface: 

  - The service expect a binary data stream. 

Output Interface:

  - A HiRPC request as HiBON Dcoument. 
  - Receiving interface: [Collector](documents/architecture/Collector.md)

The responsibilities of the service are:

  - Check the data package comply with size limitation.
  - Deserialise the data to a HiBON document
  - Checks the method is supported
  - Validates the signature on the HiRPC request

The acceptance criteria specification can be found in [Transaction_services](/bdd/tagion/testbench/services/Transaction_service.md)
