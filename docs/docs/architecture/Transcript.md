# Transcript Service

This service is responsible for producing a Recorder ensuring correct inputs and output archives including no double input and output in the same Epoch and sending it to the DART.

Input:
  - Receives an Epoch list contaning ordered events from the [Epoch Creator](/documents/architecture/EpochCreator.md).
  - Receives all Draft outputs archives from the [TVM](/documents/architecture/TVM.md).

Request:
  - Request to all the inputs archives from the [DART](/documents/architecture/DART.md).

Output:
  - A DART-recorder is sent to the [DART](/documents/architecture/DART.md)

This services performs the following:
```{r, eval=FALSE,tidy=FALSE}
Collect all the inputs/output archives related to the contract
WHEN an list of $epochs has been received 
    Clear the input used list
    LOOP through each contract in the Epoch list
        IF inputs of the contract exists in the DART and is not in the used list THEN
            Mark the input archives as remove in the Recorder.
            Add the epoch number to the output archives.
            Mark the output archives as add in the Recorder.
            Add the inputs to the used list
        END
    END
    Send the Recorder to the DART.

```
The acceptance criteria specification can be found in [Transcript_services](/bdd/tagion/testbench/services/ContractInterface_service.md).

```mermaid
sequenceDiagram
    participant TVM 
    participant Epoch Creator 
    participant Transcript
    participant DART 
    TVM ->> Transcript: Contract + Inputs/Outputs
    Epoch Creator ->> Transcript: Epoch list  
    Transcript ->> DART:  Verify all inputs 
    DART ->> Transcript : List of invalid inputs 
    Transcript ->> DART: Recorder(Modifiy)
```

