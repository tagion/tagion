# Hash invariant Remote Procedure Call

The HiPRC is inspired by JSON-RPC just that it is base on the HiBON format and it can include digital signatures which enables the receiver to validate the credentials.


## Description of HiRPC format

| Name    | Type | Description |  Optional |
| ------  | ----- | ----------- | --- |
| `$sign` | * | Digital signature | |
| `$pkey` | * | Permission public key | |
| `$msg`  | doc | RPC function call | |


HiRPC `$msg` comes in 3 types. [Method](Method), [Result](Result) and [Error](Error).

### Method
| Name | Type | Description | Optional|
| ---- | ----- | ------- | --- |
| `method` | str | RPC method name | |
| `id`     | uint | Remote id number | |
| `params` | doc | parameter argument as a Document | |


### Result
| Name | Type | Description | Optional|
| ---- | ----- | ------- | --- |
| `id ` |  | | |
| `result` | doc | Result for the RPC as a Document | |

### Error
| Name | Type | Description | Optional|
| ---- | ----- | ------- | --- |
| `id` |
| `$data` |
| `$msg` |
| `$code` |

