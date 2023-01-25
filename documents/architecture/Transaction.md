# Transaction services

This services handles the pre-validation of the smart-contract.

The smart contract is package into a [HiPRC](HiRPC.md).
./bdd/tagion/testbench/

This services should perform the following.

1. Check that the received package is the correct [HiBON](HiRPC.md) formatQ

2. Check that the package is a HiRPC.

3. Convert the Document in to a HiRPC and send it to the [Collector](Collector.md)


The acceptance critiesas can be found in [Transaction_services](/bdd/testbench/services/Transaction_services.mk) is


