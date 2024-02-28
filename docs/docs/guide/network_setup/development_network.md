# Starting local networks for testing
There are a lot of individual steps in order to create a network. Therefore helper scripts exist in order to make it easier.

## Simple network
Create wallet and databases with accounting added.

```bash
mkdir /tmp/test_network/
cd /tmp/test_network/

# Script can be found in tub/scripts/create_wallets.sh

./create_wallets.sh -h // see up to date information on switches
# Usage: create_wallets.sh -b <bindir> [-n <nodes=5>] [-w <wallets=5>] [-q <bills=50>] [-k <network dir = ./network>] [-t <wallets dir = ./wallets>] [-u <key filename=./keys>]
```

Assuming you have installed the binaries in `~/bin/`.
```bash
./create_wallets.sh -b ~/bin/ 
# Run the network this way:
# ~/bin/neuewelle /tmp/test/network/tagionwave.json --keys /tmp/test/wallets < /tmp/test/keys
```
The above script command will output the neccesary steps for starting the network with `neuewelle`. 
If the shell is also going to be started with caching remember to add `--option=subscription.tags:recorder,trt_created` to the `neuewelle` command. 



