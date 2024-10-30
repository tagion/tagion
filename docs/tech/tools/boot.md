# tagionboot (stiefel)

tagionboot is a tool to bootstrap a DART.
For more comprehensive guides and usage checkout [network_setup](/docs/guide/network_setup/initialize_genesis_epoch)
and the [create_wallets script](https://github.com/tagion/tagion/blob/current/scripts/create_wallets.sh)

The alias name for this tool is `stiefel`, which is the German word for boot :boot:

```
Documentation: https://docs.tagion.org/

Usage:
tagionboot [<option>...] <hibon-files> ...

Where:
<file>           hibon outfile (Default dart.hibon)

<option>:
   --version display the version
-v --verbose Prints more debug information
-o  --output Output filename : Default dart.hibon
-p --nodekey Node channel key(Pubkey) 
-t     --trt Generate a recorder from a list of bill files for the trt
-a --account Accumulates all bills in the input
-g --genesis Genesis document
-h    --help This help information.
```

## Examples

### Create a main dart

```
dartutil -I dart.drt
cat *.hibon | stiefel -a -p Node_1,@Ajamo1PW0Ux3GiPPOZHkwXC0Cbq6nX3bOVNXW-vBa5kF,tpc://*:10700 -o dart_recorder.hibon
dartutil dart.drt -m dart_recorder.hibon
```

### Create a [TRT](/docs/architecture/TRT) dart

```
dartutil -I trt.drt
dartutil --dump dart.drt | hirep -r TGN | stiefel --trt -o trt_recorder.hibon
dartutil dart.drt -m trt_recorder.hibon
```
