# Contract definitions in Tagion Network

A contract is defined as a [HiRPC](documents/protocols/hibon/Hash_invariant_Remote_Procedure_Call.md)

 method

## Signed contract(SSC)
[SignedContract](ddoc://tagion.funnel.StandardContract.SignedContract)

| Name        | D-Type       | Description            |  Required |
| ----------- | ------------ | ---------------------- | --------- |
| `$signs`    | [Buffer]()[] | List of $N$ signature  |    Yes    |
| `$contract` | [Contract]() | The contract body      |    Yes    |

### Body of the contract(SMC) 
[Contract](ddoc://tagion.funnel.StandardContract.Contract)

| Name        | D-Type          | Description            |  Required |
| ----------- | --------------- | ---------------------- | --------- |
| `$in`       | [Buffer]()[]    | $N$ input fingerprint  |    Yes    |
| `$read`     | [Buffer]()[]    | Fingerprints to reads  |    No     |
| `$run`      | [Document]()    | Smart Contract         |    Yes    |


## The HiRPC method send to Network

The network receives a contract via as parameter to a [HiRPC](documents/protocols/hibon/Hash_invariant_Remote_Procedure_Call.md)


### Smart contract Method

| Name     | D-Type             | Description         | Required | 
| -------- | ------------------ | ------------------- | -------- |
| `method` | string="submit"    | RPC method name     |   Yes    |
| `params` | [SignedContract]() | The actual contract |   Yes    |









