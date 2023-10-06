# Tagion wallet (Geldbeutel)

```
Documentation: https://tagion.org/

Usage:
geldbeutel [<option>...] <config.json> <files>

<option>:
     --version display the version
-O --overwrite Overwrite the config file and exits
        --path Set the path for the wallet files : default 
      --wallet Wallet file : default wallet.hibon
      --device Device file : default device.hibon
        --quiz Quiz file : default quiz.hibon
-C    --create Create a new account
-c --changepin Change pin-code
-x       --pin Pincode
-h      --help This help information.
```

## Write wallet configuration file `wallet.json`
This will write a configuration file `wallet.json` and the wallet will be placed in `$HOME/wallet`.  
```
> geldbeutel -O --path $HOME/wallet/
```

## A wallet account can be create as follows

Create the wallet from a list of questions. The questions are listed in the config-file `wallet.json`
```
> geldbeutel -C

Wallet dont't exists
Press Enter
```
Create the wallet from a password.
```
> geldbeutel wallet.json -P very_secret --pin 1234
```

## Creating requests
Create payment request. Simplest form of payment.
```
> geldbeutel wallet.json -x 1234 --amount 100 -o payment_request.hibon
```
Create a invoice.

```
> geldbeutel wallet.json -x 1234 --create-invoice TEST:1000 -o invoice.hibon
```

## Pay requests
The send flag may be omitted if you do not want to send to the network directly. Instead use the outputfilename switch to save the request.
```
> geldbeutel wallet.json -x 1234 --pay payment_request.hibon --send
```

## Update wallet
There is to ways to update a wallet. Either a trt-lookup which looks up on all derivers and returns bills located on these locations. Or a normal update that looks up the fingerprints directly.
The --send flag may be omitted and use the outputfilename switch instead to store the request.

```
> geldbeutel wallet.json -x 1234 --update --send
```
trt-update. Used for invoices.

```
> geldbeutel wallet.json -x 1234 --trt-update --send
```


# Script for automatically generating genesis wallets and darts.
The following script makes it easier to create wallets and put their bills into the dart.
```
./create_wallets NUMBER OF WALLETS DART_CREATION_PATH WALLET_CREATION_PATH 
./create_wallets 7 /tmp/test/network /tmp/test
```
