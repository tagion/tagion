# Hash invariant Remote Procedure Call

The HiPRC is inspired by JSON-RPC just that it is base on the HiBON format and it can include digital signatures which enables the receiver to validate the credentials.


## Description of HiRPC format

| Name    | Type | Description |  Optional |
| ------  | ----- | ----------- | --- |
| `$sign` | BINARY | Digital signature | yes |
| `$pkey` | BINARY | Permission public key | yes |
| `$msg`  | DOCUMENT | RPC function call | no |


HiRPC `$msg` comes in 3 types. [Method](#Method), [Response](Response) and [Error](Error).

### Method
| Name | Type | Description | Optional|
| ---- | ----- | ------- | --- |
| `method` | STRING | RPC method name | no |
| `id`     | UINT32 | Message id number | yes |
| `params` | DOCUMENT | parameter argument as a Document | yes |

### Response 
| Name | Type | Description | Optional|
| ---- | ----- | ------- | --- |
| `id ` | UINT32 | Message id number | |
| `result` | DOCUMENT | Result for the RPC as a Document | |

### Error
| Name | Type | Description | Optional|
| ---- | ----- | ------- | --- |
| `id` | UINT32 | Message id number |
| `$data` | DOCUMENT | Error result as Document | |
| `$msg` | STRING | Error message as text | |
| `$code` | INT32 | Error code | |

