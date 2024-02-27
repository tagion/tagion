# Tagion payout wallet (Auszahlung)

```
Documentation: https://tagion.org/

Usage:
auszahlung [<option>...] <wallet.json> [<bill.hibon>] 

<option>:
    --version display the version
-v  --verbose Enable verbose print-out
        --dry Dry-run this will not save the wallet
-C   --create Create the wallet an set the confidence
-l     --list List wallet content
-s      --sum Sum of the wallet
     --amount Create an payment request in tagion
     --update Update wallet
   --response Response from update (response.hibon)
      --force Force input bill
    --migrate Migrate from old account to dart-index account
-h     --help This help information.
```

## A payout process are created from a collection of other wallets.

The wallets collection should be create with the `geldbeutel` as a normal wallet.

Thoese wallets will control the access to the payout-wallets.

Before the wallets can be used the wallets should have a name. The name of the access-wallet can be set via the `geldbeutel` as follows.

```
geldbeutel svend.json --name svend
```

The payout-wallets should be initialized also be initialized with the `auszahlung` as it's shown here.

```
geldbeutel wallet1.json --path path_to_wallet -O
```
The wallets are created with the `-C` switch as showns below.
```
auszahlung wallet1.json hugo.json svend.json bendt.json -C 2
```
The number 2 means that 2 out of the 3 access wallet should sign a payout.

## Generating a genesis bill
A genesis bill is generated as shown below.
```
auszahlung wallet1.json hugo.json svend.json bendt.json --amount 1e9 
```
This will create a bill in `path_to_wallet/bills/bill_0.hibon`

If the bill has been added to the network an `HiPRC` update command can be created as follows.

```
auszahlung wallet1.json hugo.json svend.json bendt.json --update
```
This command will create a with the default name called `path_to_wallet/contracts/update_update.hibon`.

This file is send to the network `dart`.

The response from the network should be used to update the wallet like.

```
auszahlung wallet1.json hugo.json svend.json bendt.json --response path_to_wallet/contracts/update_response.hibon
```

The payout-wallet account can be checked with.
```
auszahlung wallet1.json --list
```
Note. If the bill is green then the wallet has success-fully been updated.

## Payout 
The payout is perfomed with ad `.csv` delivered from the `Decard CRM` system.

The payout file should be copied into `path_to_wallet/payout`

It is recommend to `--dry and `-v` switch the first to test if the format is correct.

The following will generate the 3 `HiRPC` files which should be send to the network.
```
auszahlung wallet1.json hugo.json svend.json bendt.json path_to_wallet/payout/payout_file.csv

```
You should see the flowing files in `path_to_wallet/contracts/`.
```
path_to_wallet/contracts/path_file.hibon
path_to_wallet/contracts/path_file_update.hibon
path_to_wallet/contracts/path_file_bill_update.hibon
```

The file `path_to_wallet/contracts/path_file.hibon` should be send to the `contracts` of the network.

When the contract has been processed then the `path_to_wallet/contracts/path_file_update.hibon` should be send to `dart` of the network.

Then the account file `path_file_wallt/contracts/path_file_bill_update.hibon` should be send to `dart` of the network.

## Update the payout-wallet after the network transactions.

Check that the response for the transactions was successfull.

```
hibonutil -pc path_to_wallet/contracts/path_file_response.hibon
```

Update the payout-wallet.
```
auszahlung wallet1.json hugo.json svend.json bendt.json --response path_to_wallet/contracts/payout_file_update_response.hibon
auszahlung wallet1.json --list
```

Update the CRM `.csv` file.

```
auszahlung wallet1.json hugo.json svend.json bendt.json --response path_to_wallet/contracts/payout_file_bill_update_response.hibon path_to_wallet/payout/path_file.csv

```

This command will update the `path_file.csv` which should be used to update the CRM system.



*Note.*
If it is an old wallet `auszahlung` can migrate with the `--migrate` switch as follows.
```
auszahlung wallet_name.json --migrate
```
