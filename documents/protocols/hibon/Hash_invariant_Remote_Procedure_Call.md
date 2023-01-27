# Hash invariant Remote Procedure Call

The HiPRC is inspired by JSON-RPC just that it is base on the HiBON format and it can include digital signatures which enables the receiver to validate the credentials.


## Description of HiRPC format

| Name    | Type | Description |  Required |
| ------  | ----- | ----------- | --- |
| `$sign` | BINARY | Digital signature | No |
| `$pkey` | BINARY | Permission public key | No |
| `$msg`  | DOCUMENT | RPC function call | Yes |


HiRPC `$msg` comes in 3 types. [Method](#Method), [Response](#Response) and [Error](#Error).

### Method
| Name | Type | Description | Required |
| ---- | ----- | ------- | --- |
| `method` | STRING | RPC method name | Yes |
| `id`     | UINT32 | Message id number | No |
| `params` | DOCUMENT | parameter argument as a Document | No |

### Response 
| Name | Type | Description | Required |
| ---- | ----- | ------- | --- |
| `id ` | UINT32 | Message id number | No |
| `result` | DOCUMENT | Result for the RPC as a Document | No |

### Error
| Name | Type | Description | Required |
| ---- | ----- | ------- | --- |
| `id` | UINT32 | Message id number | Yes |
| `$data` | DOCUMENT | Error result as Document | No |
| `$msg` | STRING | Error message as text | No |
| `$code` | INT32 | Error code | Yes |

## HiRPC Receiver and Sender

The HiRPC is divided into two classifiers a sender and a receiver

### Sender 
If a HiPRC needs permission then the sender will sign the message and add the signature `$sign`.
The case the receiver does not know how is the owner, then owner-public-key `$pkey` should be added also.

### Receiver
In case of where the permission is need the receiver will check that the signature has been signed.


