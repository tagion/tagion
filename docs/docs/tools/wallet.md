# wallet (geldbeutel)

```
Documentation: https://tagion.org/

Usage:
geldbeutel [<option>...] <config.json> <files>

<option>:
          --version display the version
-v        --verbose Enable verbose print-out
-O      --overwrite Overwrite the config file and exits
             --path Set the path for the wallet files : default 
           --wallet Wallet file : default wallet.hibon
           --device Device file : default device.hibon
             --quiz Quiz file : default quiz.hibon
-C         --create Create a new account
-c      --changepin Change pin-code
-o         --output Output filename
-l           --list List wallet content
-s            --sum Sum of the wallet
             --send Send a contract to the shell
       --sendkernel Send a contract to the kernel
-P     --passphrase Set the wallet passphrase
   --create-invoice Create invoice by format LABEL:PRICE. Example: Foreign_invoice:1000
-x            --pin Pincode
           --amount Create an payment request in tagion
            --force Force input bill
              --pay Creates a payment contract
              --dry Dry-run this will not save the wallet
              --req List all requested bills
           --update Request a wallet updated
       --trt-update Request a update on all derivers
          --address Sets the address default: abstract://Node_0_CONTRACT_NEUEWELLE
           --faucet request money from the faucet
            --bip39 Generate bip39 set the number of words
             --name Sets the account name
             --info Prints the public key and the name of the account
           --pubkey Prints the public key
-h           --help This help information.
```
:::warning

The switch `-x --pin` is purely for testing purposes and should not be used when using a "real wallet". Please use the built-in stdin by not specifying the pin. 

:::

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
> geldbeutel wallet.json -P very_secret
```

## Creating requests
Create payment request. Simplest form of payment.
```
> geldbeutel wallet.json --amount 100 -o payment_request.hibon
```
Create a invoice.

```
> geldbeutel wallet.json --create-invoice TEST:1000 -o invoice.hibon
```

## Pay requests
The send flag may be omitted if you do not want to send to the network directly. Instead use the outputfilename switch to save the request.
```
> geldbeutel wallet.json --pay payment_request.hibon --send
```

## Update wallet
There is to ways to update a wallet. Either a trt-lookup which looks up on all derivers and returns bills located on these locations. Or a normal update that looks up the fingerprints directly.
The --send flag may be omitted and use the outputfilename switch instead to store the request.

```
> geldbeutel wallet.json --update --send
```
trt-update. Used for invoices.

```
> geldbeutel wallet.json --trt-read --send
```

## Sets an account name 

The account name can be change or set with the `--name` switch

```
> geldbeutel wallet.json --name wallet1
```


Check the name and the public key for the account

```
> geldbeutel wallet.json --info
wallet1:@AsyJ1_tZFNxZemBLF9vlccJcGVatc7G3KISAwJeKbIZf
```


Just to check the public key for the account

```
> geldbeutel wallet.json --pubkey
@AsyJ1_tZFNxZemBLF9vlccJcGVatc7G3KISAwJeKbIZf
```


## Faucet request

With a network running in dev mode it's possible to make faucet requests to the shell.

```
> geldbeutel wallet.json --faucet --create-invoice GIVEMEMONEY:1000
```

Updating the wallet you should now have the requested currency


# Script for automatically generating genesis wallets and darts.
The following script makes it easier to create wallets and put their bills into the dart.
```
./create_wallets.sh -b <bindir> [-n <nodes=5>] [-w <wallets=5>] [-k <network dir = ./network>] [-t <wallets dir = ./wallets>]
./create_wallets build/x86_64-linux -k /tmp/tagion-test/network -t /tmp/tagion-tagion/wallets
```
