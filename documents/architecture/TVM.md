# TVM (Tagion Virtual Machine)

The TVM is responsible for executing the instructions in the contract ensuring the contract is compliant with Consensus Rules producing outputs. 
It send new, non-consensus, contracts to the Consensus service.


Input: 

- A Contract-S (Signed) and Input Data, DART archives, received from the [Collector](/documents/architecture/Collector.md) Service.

Output:

- A Contract-SC (Signed Consensus) that is compliant with Consensus Rules sent to the [Epoch Creator](/documents/architecture/EpochCreator.md) Service.

- The input and draft output DART archives is sent to Transcript Service.

The service does the following:

- Loads the Consensus Rules (only Tagion to start with).
- Loads the input data.
- Executes the instruction(s).
    - Ensures the intructions are valid.
    - Ensures the intructions follow the Consensus Rules.
    - Executes the instructions and produces output draft archives
- If the Sends the Contract-SC to the network without data.
- Sends output draft archives and input archives to Transcript Service.