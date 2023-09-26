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
~/wallets> geldbeutel wallet1.json -x 1234
Pincode correct
```


