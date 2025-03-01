# TVM (Tagion Virtual Machine)

The TVM is responsible for executing the instructions in the contract ensuring the contract is compliant with Consensus Rules producing outputs. 
It send new, non-consensus, contracts to the Epoch Creator Service.
The outputs produced by the contract are send to the Transcript Service. 


Input: 

- A Contract-S (Signed) and DART archives received from the [Collector](/tech/architecture/Collector) Service.
- A Contract-SC (Signed Consensus) and DART archives received from the [Collector](/tech/architecture/Collector) Service.

Output:

- A Contract-SC (Signed Consensus) that is compliant with Consensus Rules sent to the [Epoch Creator](/tech/architecture/EpochCreator) Service.
- The draft output and input DART archives is sent to [Transcript](/tech/architecture/Transcript) Service.

The service does the following:

- Loads the Consensus Rules (only Tagion to start with).
- Loads the input data.
- Executes the instruction(s).
    - Ensures the instructions are valid.
    - Ensures the instructions follow the Consensus Rules.
    - Executes the instructions and produces draft output archives.
- If input was Contract-S then a Contract-SC is sent to the Epoch Creator Service.
- Sends output archives draft are send to Transcript Service.

```mermaid
sequenceDiagram
    participant Contract Interface
    participant TVM
    participant Epoch Creator
    participant Transcript
    Contract Interface ->> TVM: Contract-S + Archives(inputs)
    TVM ->> Epoch Creator: Contract+SC
    TVM ->> Transcript: Archives(inputs)+Draft output Archives 
```
