# Contract tracing proposal

## Current problems with tracing
Currently if you want to know if a contract has gone through or not, the only way to figure it out as a client or debugger is by seeing if the inputs for the contract were deleted and the outputs added. 
Also this does not guarentee that a specific contract went through. It might have been another one.
When debugging developers also have a difficult time, since the only way to currently debug is to go through the log, which is cumbersome in cases where many contracts are sent at the same time. 


## Proposed solution
Important aspects that needs to be fulfilled with the tracing are as follows.
* The logging should use the logger-service, in order to not send the log if there are no listeners.
* It should not slow down the core, which means that the information must be pushed out from the respective services.
* It should contain different options for tracing. Allowing for pushing a (true, false) in prod if a contract has gone through. Or more verbose information in debug mode in order to see where the contract got stuck.
* You should be able to make a request to the system which can return if a contract has gone through.

It should be easily extended in order to support functionality for a future explorer.

### Tracing
The unique identifier for each contract should be the contract hash. This will be unique for all contract coming into the system. This contract hash should be logged out with a specific identifier ("CONTRACT_contract_hash"?), which allows users to subscribe to a specifc contract or all contracts. The logging should happen in all actors through the stack with the inputvalidator being the most important indicating that the contract was received. And the dart/trt telling if the contract has gone through in the end. 

### New TRT Archive
We could add a new archive to the trt which contains:
```dlang
@recordType(TYPENAME~"contract_trt")
struct TRTContract {
  @label("#CONTRACT") Buffer contract_hash; // the contract hash as a name record
  long epoch_number; // the epoch number
}

```
This will allow users to lookup if a contract has gone through with a `trt.checkRead` method. Or perform a `trt.dartRead` in order to see what epoch the contract when through.
This would also mean that contract hashes has to be stored in the recorder as well, so that the trt can be rebuilt at a later stage and not contain a state by itself.

## First steps
1. Implement logging on contracts through the stack.
2. Create a simple CLI program which will print a new line with "CONTRACT_HASH, STATE", each time a new event is created by subscribing to all contracts. This will be the base for a new debug tool in the future.  
