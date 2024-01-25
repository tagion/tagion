# Public hirpc methods

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


**Example dartRead request**
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
*Note* - The `"$Y"`, `"$sign"` are optional, but are highly recommended in order to check that the package was not tampered with.

#### Returns
hirpc.result = [RecordFactory.Recorder](https://ddoc.tagion.org/tagion.dart.Recorder.RecordFactory.Recorder)
If a specified archive was not found in the dart, it is simply not included in the output recorder.

**Example response**
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
