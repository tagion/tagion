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
| "submit"                                                     | "dartCheckRead"                                            | "log"                                                         |
|                                                              | "dartRead"                                                 |
|                                                              | "dartRim"                                                  |
|                                                              | "dartBullseye"                                             |
| **HiRPC methods subdomains**                                 | ..                                                         | ..                                                            | ..                                                         |
| ..                                                           | trt                                                        | ..                                                            | ..                                                         |
| **NNG Socket type**                                          | ..                                                         | ..                                                            | ..                                                         |
| REPLY                                                        | REPLY                                                      | PUBLISH                                                       | ???                                                        |


These are the hirpc methods exposed by the tagion kernel.

!> Missing documentation for error values

## Write methods

### submit

*HiRPC Method for submitting a contract, eg. making a transaction*  
The method will return ok if the contract was receveived, but cannot predict if the contract can be executed properly.  
The method will return an error if the document is invalid or contract has the wrong format.  

\$msg.method.name = "submit"  
\$msg.method.params = [SignedContract(SSC)](https://ddoc.tagion.org/tagion.script.common.SignedContract)

**Returns**

\$msg.result = [ResultOK](https://ddoc.tagion.org/tagion.communication.HiRPC.ResultOk)  

or

\$msg.error

## Read methods (DART(ro) + friends)

### dartCheckRead

*This method takes a list of DART Indices and responds with all of the indices which were not in the DART*

\$msg.method.name = "dartCheckRead"  
\$msg.method.params.dart_indices = [DARTIndex](https://ddoc.tagion.org/tagion.dart.DARTBasic.DARTIndex)[]  

**Returns**

\$msg.result = [DARTIndex](https://ddoc.tagion.org/tagion.dart.DARTBasic.DARTIndex)[]  

### dartRead

*This method takes a list of DART Indices and responds with a Recorder of all the archives which were in the DART*

\$msg.method.name = "dartRead"  
\$msg.method.params.dart_indices = [DARTIndex](https://ddoc.tagion.org/tagion.dart.DARTBasic.DARTIndex)[]  


**Example dartRead request**

<details>
<summary><b>Example request</b></summary>

```json
{
    "$@": "HiRPC",
    "$Y": [
        "*",
        "@AhJKNLaNgHVRgF1dEz8rWHhROYAVIntpyDasIpHVeAqE"
    ],
    "$msg": {
        "method": "dartRead",
        "params": {
            "dart_indices": [
                [
                    "*",
                    "@4c2LxGMUI7o7AnNQfKxgAEdjwizVRvdtV3j2ItiBwQM="
                ],
                [
                    "*",
                    "@oKqMX30Lf0KnzFJ46Ws5SRH48oPouDDS3IIXIaYPjkM="
                ]
            ]
        }
    },
    "$sign": [
        "*",
        "@VVKuIfWv93MZCeCwpEcrHGRNsf8RaLtJguiytuegANxyMTSiWtNGdXQsuxaCTr7hKKQbY8UXHczlNLafm1-VwQ=="
    ]
}
```

</details>


*Note* - The `"$Y"`, `"$sign"` are optional, but are highly recommended in order to check that the package was not tampered with.

#### Returns
hirpc.result = [RecordFactory.Recorder](https://ddoc.tagion.org/tagion.dart.Recorder.RecordFactory.Recorder)
If a specified archive was not found in the dart, it is simply not included in the output recorder.

<details>
<summary><b>Example response</b></summary>

```json
{
    "$@": "HiRPC",
    "$Y": [
        "*",
        "@A7l5pb4FfnnJYXW0_MDlXP-a1urQ_XC1ZCZmRAwNLGj-"
    ],
    "$msg": {
        "result": {
            "$@": "Recorder",
            "0": {
                "$T": [
                    "i32",
                    1
                ],
                "$a": {
                 // archive
                }
            },
            "1": {
                "$T": [
                    "i32",
                    1
                ],
                "$a": {
                  // archive
                }
            }
        }
    },
    "$sign": [
        "*",
        "@LoOxof1kQgjuFB188DjP-coHPqy5t26nK9Is9R2PVvhOa2Uri6VitOZkfQeKMQuH7tjn_yjLpYEsEcivKPbXDA=="
    ]
}
```

</details>

### dartRim

*This method takes a rimpath a return a Recorder with all of the branches in that rim*

\$msg.method.name = "dartRim"  
\$msg.method.params = [Rims](https://ddoc.tagion.org/tagion.dart.DARTRim.Rims)

**Returns**

\$msg.result = [RecordFactory.Recorder](https://ddoc.tagion.org/tagion.dart.Recorder.RecordFactory.Recorder)

### dartBullseye

*This method return the bullseye of the database*

\$msg.method.name = "dartBullseye"  

<details>
<summary><b>Request</b></summary>

The request takes no parameters, so this is the only thing you need

```json
{
    "$@": "HiRPC",
    "$msg": {
        "method": "dartBullseye"
    }
}
```

</details>


**Returns**

\$msg.result = [Fingerprint](https://ddoc.tagion.org/tagion.crypto.Types.Fingerprint)  

<details>
<summary><b>Example Response</b></summary>

```json
{
  "$@": "HiRPC",
  "$Y": [
    "*",
    "@AumexnPXMa0mKVsYQeEKvY4Y640DXNCuBU6XdzFOicWC"
  ],
  "$msg": {
    "result": {
      "bullseye": [
        "*",
        "@lTeI-fg_6r6v0AUSA_tDL1mJlZNlikRpBTHfd6k4qt4="
      ]
    }
  },
  "$sign": [
    "*",
    "@0cEtP0XNfxbjTKo0xx_jB5FzfYac_rHa3z-fDqCN0XdCHb3fQFR42NisU6yXiqFTSSjqHCawfmWEe9-9Bo-Wpw=="
  ]
}
```

</details>

---
