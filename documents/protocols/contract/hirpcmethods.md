# Public hirpc methods

## Connection types
By default all of these sockets are private, ie. theyre linux abstract sockets and can only by accessed on the same machine.
The socket address, and thereby the visibillity can be changed in the tagionwave config file.


| [Input Validator](/documents/architecture/InputValidator.md) | [Dart Interface](/documents/architecture/DartInterface.md) | [Subscription](/documents/architecture/LoggerSubscription.md) | [Node Interface](/documents/architecture/NodeInterface.md) |
| -                                                            | -                                                          | -                                                             | -                                                          |
| Write                                                        | Read-only                                                  | Pub                                                           | Half-duplex p2p wavefront communication                    |
| **Default shell endpoint**                                   | ..                                                         |                                                               |                                                            |
| /api/v1/contract                                             | /api/v1/dart                                               |                                                               |                                                            |
| **Default socket address (node_prefix is added in mode0)**   | ..                                                         | ..                                                            | ..                                                         |
| "\0*node_prefix*CONTRACT_NEUEWELLE"                          | "\0*node_prefix*DART_NEUEWELLE"                            | "\0SUBSCRIPTION_NEUEWELLE"                                    | tcp://localhost:10700                                      |
| **HiRPC methods**                                            | ..                                                         | ..                                                            | ..                                                         |
| "submit"                                                     | "search"                                                   | "log"                                                         |
|                                                              | "dartCheckRead"                                            |
|                                                              | "dartRead"                                                 |
|                                                              | "dartRim"                                                  |
|                                                              | "dartBullseye"                                             |
| **NNG Socket type**                                          | ..                                                         | ..                                                            | ..                                                         |
| REPLY                                                        | REPLY                                                      | PUBLISH                                                       | ???                                                        |


These are the hirpc methods exposed by the tagion kernel.

## Write methods

### submit

*HiRPC Method for submitting a contract, eg. making a transaction*  
The method will return ok if the contract was receveived, but cannot predict if the contract can be executed properly.  
The method will return an error if the document is invalid or contract has the wrong format.  

hirpc.method.name = "submit"  
hirpc.method.params = [SignedContract(SSC)](https://ddoc.tagion.org/tagion.script.common.SignedContract)  

**Returns**

hirpc.result = [ResultOK](https://ddoc.tagion.org/tagion.communication.HiRPC.ResultOk)  

or

hirpc.error

## Read methods (DART(ro) + friends)

### search (will be deprecated)

*This method takes a list of Public keys and returns the associated archives*  
This will be removed in the future in favour of a similar method which returns the list of associated DARTIndices instead
and it will be the clients reponsibillity to ask for the needed archives.
See [TIP1](/documents/TIPs/cache_proposal_23_jan)

hirpc.method.name = "search"  
hirpc.method.params = [Pubkey](https://ddoc.tagion.org/tagion.crypto.Types.Pubkey)[]  

**Returns**

hirpc.method.params = [DARTIndex](https://ddoc.tagion.org/tagion.dart.DARTBasic.DARTIndex)[]  

### dartCheckRead

*This method takes a list of DART Indices and responds with all of the indices which were not in the DART*

hirpc.method.name = "dartCheckRead"  
hirpc.method.params = [DARTIndex](https://ddoc.tagion.org/tagion.dart.DARTBasic.DARTIndex)[]  

**Return**

hirpc.result = [DARTIndex](https://ddoc.tagion.org/tagion.dart.DARTBasic.DARTIndex)[]  

### dartRead

*This method takes a list of DART Indices and responds with a Recorder of all the archives which were in the DART*

hirpc.method.name = "dartRead"  
hirpc.method.params = [DARTIndex](https://ddoc.tagion.org/tagion.dart.DARTBasic.DARTIndex)[]  

**Returns**

hirpc.result = [RecordFactory.Recorder](https://ddoc.tagion.org/tagion.dart.Recorder.RecordFactory.Recorder)

### dartRim

*This method takes a rimpath a return a Recorder with all of the branches in that rim*

hirpc.method.name = "dartRim"  
hirpc.method.params = [Rims](https://ddoc.tagion.org/tagion.dart.DARTRim.Rims)

**Returns**

hirpc.result = [RecordFactory.Recorder](https://ddoc.tagion.org/tagion.dart.Recorder.RecordFactory.Recorder)

### dartBullseye

*This method return the bullseye of the database*

hirpc.method.name = "dartBullseye"  


**Returns**

hirpc.result = [Fingerprint](https://ddoc.tagion.org/tagion.crypto.Types.Fingerprint)  
