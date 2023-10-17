# Initialize the network

## Create initial wallet

Create two initial wallets wallet via `geldbeutel`.

```
~> mkdir wallets
~> cd wallets/
~/wallets> geldbeutel -O --path ~/wallets/wallet1 wallet1.json
~/wallets> geldbeutel -O --path ~/wallets/wallet2 wallet2.json
```

The `wallet1.json` and `wallet2.json` is the config file for the wallet.

Use the UI to create passphrase for the wallets.

```
~/wallets> geldbeutel -C wallet1.json
~/wallets> geldbeutel -C wallet2.json
```

Check the passphrase.
```
~/wallets> geldbeutel wallet1.json -x 1234 -v
Pincode correct
```

## Add a bill to the DART
Create a simple bill.
```
~/wallets> geldbeutel wallet1.json -x 1234 --amount 10000 -o give_me.hibon
Created give_me.hibon of 10000.0
~/wallets> geldbeutel wallet1.json -x 1234 --amount 20000 -o give_me_2.hibon
Created give_me_2.hibon of 20000.0
```

Generate a DART-recorder.
```
~/wallets> stiefel give_me.hibon give_me_2.hibon -o dart_recorder.hibon
```

Create a DART database.
```
~/wallets> dartutil --initialize dart.drt
```

Add the `dart_recorder.hibon` to `dart.drt`.
```
~/wallets> dartutil dart.drt dart_recorder.hibon -m 
```

Check the content of the DART db.
```
carsten@spacepot ~/wallets> dartutil --dump dart.drt
EYE: 32c9c8e19d707d29161ffd73c907156e431de490a0b598292287e2915bdd4c26
| 07 [3]
| .. | 17 [2]
| .. | .. 0717863f3ac292a9cd78350b10714a512e558ec40212e39ad29a26c44b4a0f3c [1]
| 4E [6]
| .. | ED [5]
| .. | .. 4eedda1433a8ec363fd66fd2c9b9b03b3c46fc97eb9df67eff0c7f4a992a4732 [4]
```

List the archive in the `dart.drt`.
```
~/wallets [0|1]> dartutil dart.drt -r 0717863f3ac292a9cd78350b10714a512e558ec40212e39ad29a26c44b4a0f3c|hibonutil -p
{
    "$@": "HiRPC",
    "$Y": [
        "*",
        "@A6QHQRVMJr44VN7Sj4kL3aQB0WIov9QDgvzsBRtEGqcI"
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
                            "0x9184e72a000"
                        ]
                    },
                    "$Y": [
                        "*",
                        "@A-qiTidDR5cSqwNoLwMf0pIh3FK4b02uinKWqgn-nWUF"
                    ],
                    "$t": [
                        "time",
                        "2023-09-26T19:05:51.3632001"
                    ],
                    "$x": [
                        "*",
                        "@12zZAA=="
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
        "@5NdjJubhEYwHBLWV1B8iSLmivjn9AQYfGl4n5P7rLhl5QLYbHOlAFf9rIOm_bstA1bGvkF1iqjog3Boyv4DkWw=="
    ]
}
```

*Continued* [Initialize Genesis Epoch](/documents/network_setup/initialize_genesis_epoch.md)

