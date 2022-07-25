<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# dartutil v.0.x.x
> This tool is used for working with local DART database. It allows to read and modify directly and also can run some test scenarios in DART structure.
>
#### [Tool link](https://github.com/tagion/tagion/tree/release/src/bin-dartutil)

# Table of contents
- [dartutil v.0.x.x](#dartutil-v0xx)
      - [Tool link](#tool-link)
- [Table of contents](#table-of-contents)
  - [Exclusive functions](#exclusive-functions)
- [read](#read)
  - [Parameters](#parameters)
  - [Use cases:](#use-cases)
    - [Case: read single record](#case-read-single-record)
      - [Success](#success)
      - [Failure](#failure)
    - [Case: read several records](#case-read-several-records)
      - [Success](#success-1)
      - [Failure](#failure-1)
- [rim](#rim)
- [modify](#modify)
  - [Parameters](#parameters-1)
  - [Use cases:](#use-cases-1)
    - [Case: create new DART with executed sequence from file](#case-create-new-dart-with-executed-sequence-from-file)
      - [Success](#success-2)
      - [Failure](#failure-2)
    - [Case: execute sequence on existent DART](#case-execute-sequence-on-existent-dart)
      - [Success](#success-3)
      - [Failure](#failure-3)
- [rpc](#rpc)
  - [Parameters](#parameters-2)
  - [Use cases:](#use-cases-2)
- [nncupdate](#nncupdate)
  - [Parameters](#parameters-3)
  - [Use cases](#use-cases-3)
    - [Case: simple call](#case-simple-call)
      - [Success](#success-4)
      - [Failure](#failure-4)
- [nncread](#nncread)
  - [Parameters](#parameters-4)
  - [Use cases](#use-cases-4)
    - [Case: simple call](#case-simple-call-1)
      - [Success](#success-5)
      - [Failure](#failure-5)
- [testaddblocks](#testaddblocks)
  - [Parameters](#parameters-5)
  - [Use cases](#use-cases-5)
    - [Case: add several blocks](#case-add-several-blocks)
      - [Success](#success-6)
      - [Failure](#failure-6)
- [testdumpblocks](#testdumpblocks)
  - [Parameters](#parameters-6)
  - [Use cases](#use-cases-6)
    - [Case: dump last block](#case-dump-last-block)
      - [Success](#success-7)
      - [Failure](#failure-7)
    - [Case: dump all blocks](#case-dump-all-blocks)
      - [Success](#success-8)
      - [Failure](#failure-8)
- [version](#version)
- [dartfilename](#dartfilename)
  - [Use cases](#use-cases-7)
    - [Success](#success-9)
    - [Failure](#failure-9)
- [initialize](#initialize)
- [inputfile](#inputfile)
  - [Use cases](#use-cases-8)
    - [Case: simple call](#case-simple-call-2)
      - [Success](#success-10)
      - [Failure](#failure-10)
- [outputfile](#outputfile)
- [from](#from)
- [to](#to)
- [dump](#dump)
  - [Use cases](#use-cases-9)
    - [Case: dump DART](#case-dump-dart)
- [eye](#eye)
  - [Use cases](#use-cases-10)
    - [Case: print bullseye](#case-print-bullseye)
- [passphrase](#passphrase)
- [verbose](#verbose)

## Exclusive functions
You can call only one function from this list at a time
- [--read](#read)
- [--rim](#rim)
- [--modify](#modify)
- [--rpc](#rpc)
- [--nncupdate](#nncupdate)
- [--nncread](#nncread)
- [--testaddblocks](#testaddblocks)
- [--testdumpblocks](#testdumpblocks)
  
# read
```
--read -r
```
Reads records from DART by hash. Can take several hashes at once.<br>
DART file must exist before calling.
<br><br>
One of the [exclusive functions](#exclusive-functions) 
<br><br>
This function requires value. Takes one or several strings which are hashes in DART database.<br>
Example of using:
```
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127

./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 5d07e4bfff14a719e0b4e57dc76bfa330ffe173c9da28afa279c337a39e171d9 7d6c44500ae8d95d4287ab56cc15c85c5ddceba715648889c991b1732847ad0f
```

## Parameters

[--verbose](#verbose) **optional**

[--outputfile](#outputfile) **optional**

[--dartfilename](#dartfilename) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

## Use cases:
### Case: read single record
```
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 --verbose
```
#### Success
**Result** <br>
Found record with given hash. Written to outputfile and console:
```
Document: {
    "result": {
        "$@": "Recorder",
        "0": {
            "$a": {
                "#name": "test name",
                "$@": "NNC",
                "$Y": [
                    "*",
                    "@"
                ],
                "$lang": "",
                "$record": [
                    "*",
                    "@2S4uO+DHbbiwWJKGRZjmZfWHfSZLmEerWSMYg91gZf8="
                ],
                "$time": [
                    "u64",
                    "0x0"
                ]
            },
            "$t": [
                "i32",
                1
            ]
        }
    }
}
```
#### Failure
**Result** (when record not found)<br>
Empty recorder is written to outputfile and console
```
Document: {
    "result": {
        "$@": "Recorder"
    }
}
```

**Result** (when hash has wrong format)<br>
**Refactor** handle exception
```
core.exception.AssertError@/home/ivanbilan/work/tagion/src/lib-utils/tagion/utils/Miscellaneous.d(49): Assertion failure
----------------
??:? [0x559f9b8d6a35]
??:? [0x559f9b8ffc06]
...
```

### Case: read several records
```
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 5d07e4bfff14a719e0b4e57dc76bfa330ffe173c9da28afa279c337a39e171d9 7d6c44500ae8d95d4287ab56cc15c85c5ddceba715648889c991b1732847ad0f --verbose
```
#### Success
**Result** <br>
Found records with given hashes. Single recorder with all records is written to outputfile and console:
**Refactor** not working now, takes only first argument
```
Document: {
    "result": {
        "$@": "Recorder",
        "0": {
 ...
```
#### Failure
**Result** (when record not found)<br>
Empty recorder is written to outputfile and console
```
Document: {
    "result": {
        "$@": "Recorder"
    }
}
```

**Result** (when hash has wrong format)<br>
**Refactor** handle exception
```
core.exception.AssertError@/home/ivanbilan/work/tagion/src/lib-utils/tagion/utils/Miscellaneous.d(49): Assertion failure
----------------
??:? [0x559f9b8d6a35]
??:? [0x559f9b8ffc06]
...
```

See also use cases of parameters, used in this function

# rim
```
--rim
```
**Refactor** need to implement

# modify
```
--modify -m
```
Executes a DART modify sequency from HiBON file.<br>
DART file must exist before calling, but can be created instantly using [--initialize](#initialize)
<br><br>
One of the [exclusive functions](#exclusive-functions) 

## Parameters

[--inputfile](#inputfile) **required** HiBON file, that contains DART modify sequence

[--outputfile](#outputfile) **optional**

[--dartfilename](#dartfilename) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

## Use cases:
### Case: create new DART with executed sequence from file
```
./dartutil --initialize -m -i="tmp.hibon"
```
#### Success
**Result** <br>
Created new DART file. Executed sequence from file. Result is written to outputfile.<br>
No console output.

#### Failure
**Result** (input file has wrong format):<br>
Created new DART file. No DART sequence executed. Aborted.

**Refactor** handle exception
```
tagion.hibon.HiBONException.HiBONException@/home/ivanbilan/work/tagion/src/lib-hibon/tagion/hibon/HiBONRecord.d(700): HiBON Document format failed
----------------
??:? [0x55f55e68fa35]
??:? [0x55f55e6b8c06]
??:? [0x55f55e69911f]
...
```
Also see [--dartfilename](#dartfilename) and [--inputfile](#inputfile) for possible failures of this case.

### Case: execute sequence on existent DART
```
./dartutil -m -i="tmp.hibon"
```
#### Success
**Result** <br>
Opened DART file. Executed sequence from input file. Result is written to outputfile.<br>
No console output.

#### Failure

See [previous case](#case-create-new-dart-with-executed-sequence-from-file) failures.

Also see [--dartfilename](#dartfilename) and [--inputfile](#inputfile) for possible failures of this case.


See also use cases of parameters, used in this function

# rpc
```
--rpc
```
Executes a HiPRC on the DART.<br>
DART file must exist before calling, but can be created instantly using [--initialize](#initialize)
<br><br>
One of the [exclusive functions](#exclusive-functions) 

## Parameters

[--inputfile](#inputfile) **required** HiBON file, that contains DART modify sequence

[--outputfile](#outputfile) **optional**

[--dartfilename](#dartfilename) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

## Use cases:
TBD

# nncupdate
```
--nncupdate
```

Updates existing NetworkNameCard with given name and associated records in DART. Takes name as a parameter.<br>
Before calling `nncupdate` DART file must exist and must contain valid NetworkNameCard with given name and other associated records.<br>
One of the [exclusive functions](#exclusive-functions) 
<br><br>
This function requires value. Takes string which is a name of NetworkNameCard to be updated in DART database.<br>
Example of using:
```
./dartutil --nncupdate "test name"
```
**Refactor** forbid to use here system names (like "tagion")
## Parameters

[--verbose](#verbose) **optional**

[--dartfilename](#dartfilename) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

Example of using:
```
./dartutil --nncupdate="test name"
./dartutil --nncupdate="test name" -d="dart.drt" --verbose
```

## Use cases

### Case: simple call 
```
./dartutil --nncupdate="test name"
```
#### Success
**Result**:
NetworkNameCard with name "test name" and its associated records were updated
```
Updated NetworkNameCard with name 'test name'
```
#### Failure
**Result** (no correct signature in DART):<br>
No actions
```
WARNING: Signature for NetworkNameCard 'test name' is not verified! Unable to update record
Abort
```
**Result** (when NNC with given name not found):
```
No NetworkNameCard with name 'test name' in DART
```

See also use cases of parameters, used in this function

# nncread
```
--nncread
```

Read existing NetworkNameCard with given name and associated records from DART. Takes name as a parameter.<br>
Before calling `nncread` DART file must exist.<br>
One of the [exclusive functions](#exclusive-functions) 
<br><br>
This function requires value. Takes string which is a name of NetworkNameCard to be read in DART database.<br>
Example of using:
```
./dartutil --nncread "test name"
```
**Refactor** forbid to use here system names (like "tagion")
## Parameters

[--verbose](#verbose) **optional**

[--dartfilename](#dartfilename) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

Example of using:
```
./dartutil --nncread="test name"
./dartutil --nncread="test name" -d="dart.drt" --verbose
```

## Use cases

### Case: simple call 
```
./dartutil --nncread="test name"
```
#### Success
**Result**:
NetworkNameCard with name "test name" and its associated records were read and written to console and output file (**Refactor** now we have only output to console)
```
Found NetworkNameCard 'test name'

Signature for %s '%s' is verified

Found NetworkNameRecord for NetworkNameCard 'test name'

Found NodeAddress for NetworkNameCard 'test name'
```
#### Failure
**Result** (no correct signature in DART):<br>
NetworkNameCard with name "test name" and its associated records were read and written to console and output file (**Refactor** now we have only output to console) but with WARNING about missing signature
```
Found NetworkNameCard 'test name'

WARNING: Signature for %s '%s' is not verified!

Found NetworkNameRecord for NetworkNameCard 'test name'

Found NodeAddress for NetworkNameCard 'test name'
```
**Result** (when NNC with given name not found):
```
No NetworkNameCard with name 'test name' in DART
```

See also use cases of parameters, used in this function


# testaddblocks
```
--testaddblocks
```
Function used for debug purposes.
Add N epoch blocks to epoch chain in DART.<br>
DART file must exist and contain valid epoch block chain.<br>
One of the [exclusive functions](#exclusive-functions) 
<br><br>
This function requires value. Takes number of blocks to add.<br>
Example of using:
```
./dartutil --testaddblocks 1
./dartutil --testaddblocks 20
```
## Parameters

[--verbose](#verbose) **optional**

[--dartfilename](#dartfilename) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

## Use cases
### Case: add several blocks
```
./dartutil --testaddblocks=3
```
#### Success
**Result**<br>
N blocks was added to chain
```
Adding block 1... Done!
Adding block 2... Done!
Adding block 3... Done!
```
Also you can see added blocks in JSON format using [--verbose](#verbose)

#### Failure
**Result** (no last epoch block was found in DART)<br>
```
DART is corrupted! Top epoch block in chain was not found. Abort
```

See also use cases of parameters, used in this function.

# testdumpblocks
```
--testdumpblocks
```
Function used for debug purposes.
Dump last N epoch blocks in epoch chain in DART.<br>
Set 0 to dump all blocks in chain.<br>
DART file must exist and contain valid epoch block chain.<br>
One of the [exclusive functions](#exclusive-functions) 
<br><br>
This function requires value. Takes number of blocks to dump.<br>
Example of using:
```
./dartutil --testdumpblocks 0
./dartutil --testdumpblocks 3
```
## Parameters

[--verbose](#verbose) **optional**

[--dartfilename](#dartfilename) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

## Use cases
### Case: dump last block
```
./dartutil --testdumpblocks=1
```
#### Success
**Result**<br>
The last epoch block was read and printed to console
```
Last block is read successfully
```
Also you can see last block in JSON format using [--verbose](#verbose)

#### Failure
**Result** (no last epoch block was found in DART)<br>
```
DART is corrupted! Top epoch block in chain was not found. Abort
```

### Case: dump all blocks
```
./dartutil --testdumpblocks=0
```
#### Success
**Result**<br>
All epoch block from the last to the first were read and printed to console
```
Last block is read successfully.
N-1 epoch block is read successfully.
N-2 epoch block is read successfully.
N-3 epoch block is read successfully.
Reached first block in chain. Stop
```
Also you can see blocks in JSON format using [--verbose](#verbose)

#### Failure
**Result** (no previous block in chain was found in DART)<br>
```
DART is corrupted! Epoch block in chain was not found. Abort
```

See also use cases of parameters, used in this function.

# version
```
--version -v
```
Displays the version of tool

**Refactor** now `-v` not belongs to version, fix it

# dartfilename
```
--dartfilename -d
```
Sets the dartfile.<br>
Default value: `/tmp/default.drt`
<br>
<br>
Can be used with any function in dartutil
## Use cases
```
./dartutil <function> [implicit -d=default]
./dartutil <function> -d="dart.drt"
```
### Success
**Result**:<br>
dartutil opens specified dart file
### Failure
**Result** (when DART file can't be opened):
**Refactor** handle exception
```
std.exception.ErrnoException@std/stdio.d(758): Cannot open file `dart.drt' in mode `r+' (No such file or directory)
----------------
??:? [0x5613ca716a35]
??:? [0x5613ca73fc06]
??:? [0x5613ca72011f]
...exception output...
```
**Note**: DART file can be created using [--initialize](#initialize)

# initialize
```
--initialize
```
Creates a new DART file.<br>
Can be used as independed function or in combination with [exclusive functions](#exclusive-functions).

# inputfile
```
--inputfile -i
```
Sets the HiBON input file name.
<br><br>
Used in:
- [--rpc](#rpc)
- [--modify](#modify)

## Use cases
### Case: simple call
```
./dartutil <function> -i "tmp.txt"
```
#### Success
**Result**:
file at the specified path was opened.<br>
No console output
#### Failure
**Result** (when file not found):<br>
Tool stop working
```
Can't open input file 'tmp.txt'. Abort
```

# outputfile
```
--outputfile -o
```
Sets the output file name.<br>
Output file could have any extension. Dartutil writes output in HiBON format.<br>
To open output file using `hibonutil` it should have extenson `.hibon`.

Default value: path generated with random seed. Variants of this path:
```
/tmp/deleteme.dmd.unittest.pid277FFE000372B8
/tmp/deleteme.dmd.unittest.pid277FFE000372BC
```

Can be used with any function in dartutil

# from
```
--from
```
Sets _from_ sector angle for DART in range 0:65535.<br>
This meant to support sharding of the DART but now it's not fully supported yet.<br>

**Refactor** add assertion and text message that this feature not supported yet

Values when `from == to` means full.<br>
Default value: `0`

In development.

# to
```
--to
```
Sets _to_ sector angle for DART in range 0:65535.<br>
This meant to support sharding of the DART but now it's not fully supported yet.<br>

**Refactor** add assertion and text message that this feature not supported yet

Values when `from == to` means full.<br>
Default value: `0`

In development.

# dump
```
--dump
```
Dumps all the archives from DART.
<br><br>
Can be used with any function in dartutil

## Use cases
### Case: dump DART
```
./dartutil --dump
```
**Result**
```
EYE: 29a444af19221a7ed3dbb6e459a946745feace5a300a5390c2e48b6b27047d3d
| 1E [3]
| .. | F4 [2]
| .. | .. 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 [1]
| 5D [6]
| .. | 07 [5]
| .. | .. 5d07e4bfff14a719e0b4e57dc76bfa330ffe173c9da28afa279c337a39e171d9 [4]
| 7D [9]
| .. | 6C [8]
| .. | .. 7d6c44500ae8d95d4287ab56cc15c85c5ddceba715648889c991b1732847ad0f [7]
| 9D [12]
| .. | E0 [11]
| .. | .. 9de041ad54986f7d82598249e4bb8f1eafa8bfbd14ee31e99b8a0dabe479fe9f [10]
...
```
# eye
```
--eye
```
Prints the bullseye of DART
<br><br>
Can be used with any function in dartutil

## Use cases
### Case: print bullseye
```
./dartutil --eye
```
**Result**
```
EYE: 29a444af19221a7ed3dbb6e459a946745feace5a300a5390c2e48b6b27047d3d
```

# passphrase
```
--passphrase -P
```
Passphrase of the keypair when creating net. Takes text string.<br>
Default value: `"verysecret"`
<br><br>
Can be used with any function in dartutil

# verbose
```
--verbose -v
```
Boolean flag, that enables more detailed output to console<br>
Default value: `False`

Can be used with any function in dartutil

Example of using this flag:

**Without verbose**
```
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127
```
**Result**: no output to console

**With verbose**
```
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 --verbose
```
**Result**:
```
Document: {
    "result": {
        "$@": "Recorder",
        "0": {
            "$a": {
                "#name": "test name",
                "$@": "NNC",
                "$Y": [
                    "*",
                    "@"
                ],
                "$lang": "",
                "$record": [
                    "*",
                    "@2S4uO+DHbbiwWJKGRZjmZfWHfSZLmEerWSMYg91gZf8="
                ],
                "$time": [
                    "u64",
                    "0x0"
                ]
            },
            "$t": [
                "i32",
                1
            ]
        }
    }
}
```
