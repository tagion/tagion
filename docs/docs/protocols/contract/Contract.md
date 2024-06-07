---
title: contract
---

# Tagion Contract definitions

A contract is defined as a [HiRPC](https://www.hibon.org/posts/hirpc) with the [`submit`](/docs/protocols/hirpcmethods#submit) method and a SignedContract as the only parameter

## Smart contract Method

The hirpc document sent to the network

| Name     | D-Type             | Description         | Required | 
| -------- | ------------------ | ------------------- | :------: |
| `$@`     | hirpc         | Record type name       |   Yes    |
| `method` | string="submit"    | RPC method name     |   Yes    |
| `params` | SignedContract | The actual contract |   Yes    |


## Signed contract(SSC)
[SignedContract](https://ddoc.tagion.org/tagion.script.common.SignedContract)

| Name        | D-Type       | Description            |  Required |
| :---------: | ------------ | ---------------------- | :-------: |
| `$@`        |  SSC         | Record type name       |   Yes    |
| `$signs`    | [Buffer] | List of $N$ signature  |    Yes    |
| `$contract` | [Contract] | The contract body      |    Yes    |

### Body of the contract(SMC) 
[Contract](https://ddoc.tagion.org/tagion.script.common.Contract)

| Name        | D-Type          | Description            |  Required |
| :---------: | --------------- | ---------------------- | :-------: |
| `$@`        |  SMC         | Record type name       |   Yes    |
| `$in`       | [Buffer]    | $N$ input fingerprint  |    Yes    |
| `$read`     | [Buffer]    | Fingerprints to reads  |    No     |
| `$run`      | [Document]    | Smart Contract         |    Yes    |


### PayScript
[PayScript](https://ddoc.tagion.org/tagion.script.common.PayScript)

This is a builtin <sup>*not so*</sup>smart-contract for outputting tagions

| Name        | D-Type          | Description            |  Required |
| :---------: | --------------- | ---------------------- | :-------: |
| `$@`        |  pay         | Record type name       |   Yes    |
| `$vals`       | [TagionBill]    | script outputs  |    Yes    |


