# Hash invariant Remote Procedure Call

The HiPRC is inspired by JSON-RPC just that it is base on the HiBON format and it can include digital signatures which enables the receiver to validate the credentials.


## Description of HiRPC format

| Name    | Type     | D-Type                                            | Description           | Required |
| ------- | -------- | ------------------------------------------------- | --------------------- | -------- |
| `$sign` | BINARY   | Buffer                                            | Digital signature     | No       |
| `$pkey` | BINARY   | Pubkey                                            | Permission public key | No       |
| `$msg`  | DOCUMENT | [Document](ddoc://tagion.hibon.Document.Document) | RPC function call     | Yes      |

See [HiRPC](ddoc://tagion.communication.HiRPC.HiRPC)

HiRPC `$msg` comes in 3 types. [Method](#Method), [Response](#Response) and [Error](#Error).

### Method
| Name     | Type     | D-Type                                            | Description                      | Required |
| -------- | -------- | ------------------------------------------------- | -------------------------------- | -------- |
| `method` | STRING   | string                                            | RPC method name                  | Yes      |
| `id`     | UINT32   | uint                                              | Message id number                | No       |
| `params` | DOCUMENT | [Document](ddoc://tagion.hibon.Document.Document) | parameter argument as a Document | No       |

See [Method](ddoc://tagion.communication.HiRPC.HiRPC.Method)

### Response 
| Name     | Type     | D-Type                                            | Description                      | Required |
| -------- | -------- | ------------------------------------------------- | -------------------------------- | -------- |
| `id `    | UINT32   | uint                                              | Message id number                | No       |
| `result` | DOCUMENT | [Document](ddoc://tagion.hibon.Document.Document) | Result for the RPC as a Document | Yes      |

See [Response](ddoc://tagion.communication.HiRPC.HiRPC.Response)

### Error

| Name    | Type     | D-Type                                            | Description              | Required |
| ------- | -------- | ------------------------------------------------- | ------------------------ | -------- |
| `id`    | UINT32   | uint                                              | Message id number        | Yes      |
| `$data` | DOCUMENT | [Document](ddoc://tagion.hibon.Document.Document) | Error result as Document | No       |
| `$msg`  | STRING   | string                                            | Error message as text    | No       |
| `$code` | INT32    | int                                               | Error code               | Yes      |

See [Error](ddoc://tagion.communication.HiRPC.HiRPC.Error)

## HiRPC Receiver and Sender

The HiRPC is divided into two classifiers a sender and a receiver

### Sender 
If a HiPRC needs permission then the sender will sign the message and add the signature `$sign`.
The case the receiver does not know how is the owner, then owner-public-key `$pkey` should be added also.

See [Sender](ddoc://tagion.communication.HiRPC.HiRPC.Post)

### Receiver
In case of where the permission is need the receiver will check that the signature has been signed.

See [Receiver](ddoc://tagion.communication.HiRPC.HiRPC.Post)


