# tagionwave [Tagion full-node]

tagionwave/neuewelle is the tagion node program.
Currently only mode0 is supported [network modes](/docs/architecture/network_modes)

```bash
Help information for tagion wave program
Usage: neuewelle <tagionwave.json>

    --version Print revision information
-O --override Override the config file
     --option Set an option
-k     --keys Path to the boot-keys in mode0
-v  --verbose Enable verbose print-out
-n      --dry Check the parameter without starting the network (dry-run)
-m  --monitor Enable the monitor
-h     --help This help information.

```

The intended way to run the node is with the systemd service included in the installation.
Running the node manually is mostly useful for development and debugging.
The service can be accessed with the following commands.
```bash
systemctl enable --user neuewelle   # Automatically starting the service on boot
systemctl disable --user neuewelle  # Not starting the service at boot
systemctl start --user neuewelle    # Start the service
systemctl stop --user neuewelle     # Stop the service
```

## Examples

### Set some options and write it to the config file
```bash
neuewelle -O \
    --option=trt.enable:true
    --option=wave.fail_fast:true \
    --option=subscription.tags:taskfailure
```


### Start the network in mode0

```
neuewelle wavedir/tagionwave.json --keys wallets/
```

This start the network by loading a config file and specifying a directory to search for wallets configs. 
The program will sets its working directory to the directory of the config file. If no config file is specified it will look for a file called `tagionwave.json` in the current working directory, if none is found it'll use the default options.

The program will prompt you for a wallet configs and passwords. Where the walletconfig is specified without the `.json` file extension and separated by a colon. like this
```
node1_config:secretpassword
```

Also note that the passwords can be redirected from a password/secrets manager
```
pass node_keys | neuewelle ...
```


### Synchronized mode0 network stop 

For a synchronized mode0 stop you can specify a future epoch where the nodes should stop by putting the epoch number in a file in `/tmp/epoch_shutdown_PID`
```
echo 10000 > /tmp/epoch_shutdown$(pgrep neuewelle)
```

## Common Errors


### Missing dartfile ./Node_0_dart.drt
This mean that the nodes nodes could not find a dart database. 
For testing the database should be created with the boot tool [Initialize DART](/docs/guide/network_setup/initialize_dart) or with the helper script `create_wallets.sh`


### DATABASES must be booted with same bullseye - Abort
This means that the databases were not synchronized. Mode0 does not automatically synchronize the databases on startup. It can be synchronized with [dartutil](/docs/tools/blockutil).  
To prevent this from happening, you can make sure that the network is stopped synchronously by setting the epoch number as explained above.
