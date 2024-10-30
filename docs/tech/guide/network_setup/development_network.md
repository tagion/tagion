# Starting local networks for testing
There are a lot of individual steps in order to create a network. Therefore helper scripts exist in order to make it easier.

## Simple network
Create wallet and databases with accounting added.

```bash
# Script can be found in scripts/create_wallets.sh

./scripts/create_wallets.sh -h // see up to date information on switches
Usage: ./scripts/create_wallets.sh
        -b <bindir, default is to search in user PATH>
        -n <nodes=5>
        -w <wallets=5>
        -q <bills=50>
        -k <data dir = ./ >
        -u <key filename=./keys>
        -m <network_mode = 0>
```

Assuming you have installed the binaries in `~/bin/`.
```bash
./create_wallets.sh -b ~/bin/ 
# Run the network this way:
# ~/bin/neuewelle ./mode0/tagionwave.json --keys $PWD/mode0 < keys
```
The above script command will output the necessary steps for starting the network with `neuewelle`. 
If the shell is also going to be started with caching remember to add `--option=subscription.tags:recorder,trt_created` to the `neuewelle` command. 
