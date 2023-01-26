# Transaction services

This services handles the pre-validation of the smart-contract.
The smart contract is package into a [HiPRC](documents/protocols/hibon/Hash_invariant_Remote_Procedure_Call.md).

This services should perform the following.

1. Check that the received package is the correct [HiBON](documents/protocols/hibon/Hash_invariant_Binary_Object_Notation.md) formatQ

2. Check that the package is a HiRPC.

3. Convert the Document in to a HiRPC and send it to the [Collector](Collector.md)


The acceptance critiesas can be found in [Transaction_services](bdd/tagion/testbench/services/Transaction_service.md)


