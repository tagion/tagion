# Initialize the network

## Create initial wallet

Create two initial wallets wallet via `geldbeutel`.

```
mkdir wallets
cd wallets/
geldbeutel -O --path ~/wallets/wallet1 wallet1.json
geldbeutel -O --path ~/wallets/wallet2 wallet2.json
```

The `wallet1.json` and `wallet2.json` is the config file for the wallet.

Use the UI to create passphrase for the wallets.

```
geldbeutel -C wallet1.json
geldbeutel -C wallet2.json
```

Check the passphrase.
```
geldbeutel wallet1.json -x 0001 -v
# Config file wallet1.json
# Loggedin
```

## Add a bill to the DART
Create a simple bill.
```
geldbeutel wallet1.json -x 0001 --amount 1000000000 -o give_me.hibon
# Created give_me.hibon
geldbeutel wallet2.json -x 0002 --amount 900000000 -o give_me_2.hibon
# Created give_me_2.hibon
```

Generate a DART-recorder.
```
stiefel give_me.hibon give_me_2.hibon -o dart_recorder.hibon
```

Create a DART database.
```
dartutil --initialize dart.drt
```

Add the `dart_recorder.hibon` to `dart.drt`.
```
dartutil dart.drt dart_recorder.hibon -m 
```

Check the content of the DART db.
```
dartutil --dump dart.drt
EYE: ee8e750cfa2a1a3ef17e52fd922ffd5564e716ae1b2d7c9b4cbc108bb2594f9f
| 42 [3]
| .. | 5F [2]
| .. | .. 425f9fc079d0aeaf6d0fc57d7c22de23b40da0bd58475aaf21b45ff320f47ad6 [1]
| 5D [6]
| .. | F0 [5]
| .. | .. 5df0344514b46b2cb7d4e507a2cf34ed5c3cd23fc6f16431ec3761fc95c95a6d [4]
```

List the archive in the `dart.drt`.
```
dartutil dart.drt -r 425f9fc079d0aeaf6d0fc57d7c22de23b40da0bd58475aaf21b45ff320f47ad6|hibonutil -cp
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
                    "$@": "TGN",
                    "$V": {
                        "$": [
                            "i64",
                            "0xc7d713b49da0000"
                        ]
                    },
                    "$Y": [
                        "*",
                        "@AxExkkpbuNSj3Pb_9L3PQVrgP5OdZUJC6HSgZCdutRRN"
                    ],
                    "$t": [
                        "time",
                        "2023-10-17T15:50:16.6598183"
                    ],
                    "$x": [
                        "*",
                        "@SVFf4Q=="
                    ]
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
        "@q3TFaoVOI5YuQekvP7KKWE8t4YDyoY4x2S5F1VFIJIFeWjmxBrV_NxABudjeCiKNz4Lo3UBxG9MGnsYzp4OwjA=="
    ]
}
```

*Continued* [Initialize Genesis Epoch](/documents/network_setup/initialize_genesis_epoch.md)

