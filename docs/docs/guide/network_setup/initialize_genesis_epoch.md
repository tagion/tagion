# Initialize Genesis Epoch (low level)

*Initialize bills* [Initialize DART](/docs/guide/network_setup/initialize_dart)

## Create the epoch genesis data
The Genesis information is generated with stiefel command.

A list of node identifier `node_name_record,pubkey,address` should be create.

Atleast number active node N should be defined.

Here is an example with two node identifiers **(Note in practice the minimum should be 5)**

Example.
```
stiefel -p node_name_1,@XfA0RRS0ayy31OUHos807Vw80j_G8WQx7Ddh_JXJWm0=,ftp://ftp.smart.com -p node_name_2,@Ql-fwHnQrq9tD8V9fCLeI7QNoL1YR1qvIbRf8yD0etY=,http://tagion.org -o recorder_genesis.hibon
````

## Add the genesis data to the DART.

Apply the `recorder_genesis.hibon` create by `stiefel`.
```
dartutil dart.drt recorder_small.hibon -m
```

List inspect the DART content.

```
dartutil dart.drt --print

EYE: 462ee54f0468b9de0456c56642c8e59e71c3a52397a907013fd7949ee9f3542c
| 0A [12]
| .. | B7 [11]
| .. | .. 0ab74466913a7abef3afb6bda64bd296c7a5a758ae0e74aca89d512d2a995eaa [10] #
| 28 [15]
| .. | 59 [14]
| .. | .. 28591ef9f6ca1c608b850b58ba30f483f8d32d5bd3d8868affed85877b8f5243 [13] #
| 41 [18]
| .. | D9 [17]
| .. | .. 41d9b3fc497d6847ee67e87cfcbac1c9840d3173750d6c3f467962644f719a16 [16] #
| 42 [3]
| .. | 5F [2]
| .. | .. 425f9fc079d0aeaf6d0fc57d7c22de23b40da0bd58475aaf21b45ff320f47ad6 [1]
| 5D [6]
| .. | F0 [5]
| .. | .. 5df0344514b46b2cb7d4e507a2cf34ed5c3cd23fc6f16431ec3761fc95c95a6d [4]
| B1 [21]
| .. | 8D [20]
| .. | .. b18d0ce74b5383b888ea7e115f5ddae75482ae0d436bb7a57ac22cdd9811cff9 [19] #
| FE [24]
| .. | 9F [23]
| .. | .. fe9fb2737fde1dac8ec0815142381ff9e26a2fdf5e2b73a956dd6b6b5283f7d3 [22] #
```

The genesis epoch is locates at named-key `#$epoch` `0` and because the epoch number is a 64bits signed the type is `i64`.

The dartutil will as default return the result as an dart-recorder. 

- Note. that '$' and '#' sigens needs an escape '\\'.
```
dartutil dart.drt -r\#\$epoch:i64:0 |hibonutil -pc

{
    "$@": "HiRPC",
    "$Y": [
        "*",
        "@Av2fcgwMGh3blxvHL9mnVz81SZ9AC_-zVhNK1MD2Asea"
    ],
    "$msg": {
        "result": {
            "$@": "Recorder",
            "0": {
                "$a": {
                    "#$epoch": [
                        "i64",
                        "0x0"
                    ],
                    "$@": "$@G",
                    "$t": [
                        "time",
                        "2023-10-17T16:28:24.5068743"
                    ],
                    "nodes": [
                        [
                            "*",
                            "@XfA0RRS0ayy31OUHos807Vw80j_G8WQx7Ddh_JXJWm0="
                        ],
                        [
                            "*",
                            "@Ql-fwHnQrq9tD8V9fCLeI7QNoL1YR1qvIbRf8yD0etY="
                        ]
                    ],
                    "testamony": {}
                },
                "$t": [
                    "i32",
                    1
                ]
            }
        }
    },
    "$sign": [
        "*",
        "@zOJ95RwclkGfr5oFMCWbFn-YHfLwAaJ2QMFBha24sdo1dGlzOoMN4Fa4_Qz3-UB4GlF-05SmSErIRLYFY_crvQ=="
    ]
}
```

The name record for "node_name_1" can be read for the as follows.

- Note: the --strip removed the *HiPRC* header.

```
dartutil dart.drt -r name:node_name_1 --strip|hibonutil -pc

{
    "#name": "node_name_1",
    "$@": "NNC",
    "$Y": [
        "*",
        "@XfA0RRS0ayy31OUHos807Vw80j_G8WQx7Ddh_JXJWm0="
    ],
    "$lang": "en",
    "$record": [
        "*",
        "@"
    ],
    "$t": [
        "time",
        "2023-10-17T16:28:24.5068743"
    ]
}
```
The node-record can be read from the DART with the nodes public key as:

```
dartutil dart.drt -r\#\$node:\*:@Ql-fwHnQrq9tD8V9fCLeI7QNoL1YR1qvIbRf8yD0etY= --strip |hibonutil -pc
{
    "#$node": [
        "*",
        "@Ql-fwHnQrq9tD8V9fCLeI7QNoL1YR1qvIbRf8yD0etY="
    ],
    "$@": "$@NNR",
    "$addr": "http:\/\/tagion.org",
    "$name": "node_name1",
    "$state": [
        "i32",
        4
    ],
    "$t": [
        "time",
        "2023-10-17T16:28:24.5068743"
    ]
}
```
