# recorderchain v.0.x.x
> This tool is used to recover DART database using recorder chain.

This tool can create new DART database and recover it using recorder chain blocks.

To have recorder chain blocks generated you should specify parameter `recorderchain` on startup for tagionwave tool. This parameter specifies folder for recorder chain blocks.
<br>**Each node should have its own folder!**

To recover DART database using genesis DART file and recorder chain you can use command:
```
recorderchain -d dart.drt -c /recorder_chain_folder/ -g genesis.drt
```
After this command in case of success you will have newly created DART file with name `-d`, recovered using genesis DART file `-g` and recorder chain `-c`.

# chaindirectory
```
--chaindirectory -c
```
**Required**

Specifies directory that contains recorder chain blocks

## Use cases:
### Case: recover DART with specified chain directory
```
./recorderchain -c /directory_path/ -d dart.drt -g genesis.drt
```
#### Success
**Result**
Chain inside directory is valid and tool recovered DART file using blocks from the directory

#### Failure
**Result**(When chaindirectory path not exist)<br>
```
Recorder chain directory 'directory_path/' does not exist
```

**Result**(When recorder chain inside directory is invalid)<br>
```
Recorder block chain is not valid!
Abort
```

**Result**(When directory has no block files)<br>
```
No recorder chain files
```

# dartfile
```
--dartfile -d
```
**Required** 
Name of DART file to recover

## Use cases
### Case: recover DART with specified name
```
./recorderchain -d dart.drt -c /directory_path/ -g genesis.drt
```
#### Success
**Result**<br>
DART database created and synchronized with recorder blocks

#### Failure
**Result**(error during recovering DART from blocks)<br>
```
DART fingerprint must be the same as recorder block bullseye. Abort
```


# genesisdart
```
--genesisdart -g
```
**Required** 
Path to genesis DART file

## Use cases
### Case: recover DART with specified genesis DART file
```
./recorderchain -g genesis.drt -d dart.drt -c /directory_path/
```
#### Success
**Result**
New DART database created and synchronized with recorder blocks and genesis file

#### Failure
**Result**(genesis file doesn't exist or has incorect extension)
```
Incorrect genesis DART file 'genesis.drt'
```

**Result**(genesis file has invalid format and can't be opened)
```
Invalid format of genesis DART file 'genesis.drt'
```

