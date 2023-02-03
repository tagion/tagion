# Contract definitions in Tagion Network

When

## Signed contract(SSC)
[SignedContract](tagion.funnel.StandardContract.SignedContract)

| Name        | D-Type     | Description            |  Required |
| ----------- | -------- | ---------------------- | --------- |
| `$signs`    | [Buffer]()[] | List of $N$ signature  |    Yes    |
| `$contract` | [Contract]() | The contract body               |    Yes    |

### Body of the contract(SMC) 
[Contract](tagion.funnel.StandardContract.Contract)

| Name        | D-Type        | Description            |  Required |
| ----------- | ----------- | ---------------------- | --------- |
| `$in`       | [Buffer]()[]    | $N$ input fingerprint  |    Yes    |
| `$read`     | [Buffer]()[]    | Fingerprints to reads  |    No     |
| `$out`      | [Pubkey]()[]    | List of output pkeys   |    Yes    |
| `$run`      | string      | Contract function name |    Yes    |


## The HiRPC method send to Network

The network receives a contract via as parameter to a [HiRPC](/document/protocols/hibon/Hash_Invarian_Remote_Procedure_Call.md)

### Method

| Name | D-Type | Description | 
| ---- | ----- | ------- | 
| `method` | string | RPC method name | 
| `params` | [SignedContract]() | The actual | 









