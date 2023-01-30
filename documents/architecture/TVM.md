# TVM (Tagion Virtual Machine)

The TVM is responsible for executing the instructions in the contract ensuring the contracts are compliant with Consensus Rules producing outputs. 
It send new, non consensus, contracts to the Consensus service.


Input: 

- A Contract-S and Input Data, DART archives, received from the [Collector](/documents/architecture/Collector.md) Service.

Output:

- A Contract-SC that is compliant with Consensus Rules sent to the [Consensus](/documents/architecture/Consensus.md) Service.

- The input and output DART archives.
- Receiver: Transcript Service.

The service does the following:

- Loads the Consensus Rules (only Tagion to start with).
- Loads the input data.
- Execute the instruction(s).
    - Ensures the intructions are valid.
    - Ensures the intructions follow the Consensus Rules.
- Send the Contract-SC to the network without data.
- Send output data and input data to Transcript Service.