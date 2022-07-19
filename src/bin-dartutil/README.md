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
- [rpc](#rpc)
  - [Parameters](#parameters-2)
  - [Use cases:](#use-cases-2)
- [generate](#generate)
  - [Parameters](#parameters-3)
  - [Use cases](#use-cases-3)
    - [Case: simple call](#case-simple-call)
      - [Success](#success-3)
      - [Failure](#failure-2)
- [nncupdate](#nncupdate)
  - [Parameters](#parameters-4)
  - [Use cases](#use-cases-4)
    - [Case: simple call](#case-simple-call-1)
      - [Success](#success-4)
      - [Failure](#failure-3)
- [nncread](#nncread)
  - [Parameters](#parameters-5)
  - [Use cases](#use-cases-5)
    - [Case: simple call](#case-simple-call-2)
      - [Success](#success-5)
      - [Failure](#failure-4)
- [testaddblocks](#testaddblocks)
  - [Parameters](#parameters-6)
  - [Use cases](#use-cases-6)
    - [Case: add several blocks](#case-add-several-blocks)
      - [Success](#success-6)
      - [Failure](#failure-5)
- [testdumpblocks](#testdumpblocks)
  - [Parameters](#parameters-7)
  - [Use cases](#use-cases-7)
    - [Case: dump last block](#case-dump-last-block)
      - [Success](#success-7)
      - [Failure](#failure-6)
    - [Case: dump all blocks](#case-dump-all-blocks)
      - [Success](#success-8)
      - [Failure](#failure-7)
- [version](#version)
- [dartfilename](#dartfilename)
  - [Use cases](#use-cases-8)
    - [Success](#success-9)
    - [Failure](#failure-8)
- [initialize](#initialize)
- [inputfile](#inputfile)
  - [Use cases](#use-cases-9)
    - [Case: simple call](#case-simple-call-3)
      - [Failure](#failure-9)
- [outputfile](#outputfile)
- [from](#from)
  - [Use cases](#use-cases-10)
    - [Case: value out of range](#case-value-out-of-range)
      - [Failure](#failure-10)
- [to](#to)
  - [Use cases](#use-cases-11)
- [useFakeNet](#usefakenet)
- [dump](#dump)
- [eye](#eye)
- [width](#width)
- [rings](#rings)
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

## Parameters

[--read](#read) **required** Function takes single string (or array of strings) that represents hash value of record to read from DART.

[--verbose](#verbose) **optional**

And also common parameters for dartutil tool:

[--outputfile](#outputfile) **optional**

[--dartfilename](#dartfilename) **optional**

[--from](#from) **optional**

[--to](#to) **optional**

[--useFakeNet](#usefakenet) **optional**

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
**Refactor** not implemented now

# modify
```
--modify -m
```
Executes a DART modify sequency from hibon file.<br>
DART file must exist before calling, but can be created instantly using [--initialize](#initialize)
<br><br>
One of the [exclusive functions](#exclusive-functions) 

## Parameters

[--inputfile](#inputfile) **required** hibon file, that contains DART modify sequence

And also common parameters for dartutil tool:

[--outputfile](#outputfile) **optional**

[--dartfilename](#dartfilename) **optional**

[--from](#from) **optional**

[--to](#to) **optional**

[--useFakeNet](#usefakenet) **optional**

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

See also use cases of parameters, used in this function

# rpc
```
--rpc
```
Excutes a HiPRC on the DART.<br>
DART file must exist before calling, but can be created instantly using [--initialize](#initialize)
<br><br>
One of the [exclusive functions](#exclusive-functions) 

## Parameters

[--inputfile](#inputfile) **required** hibon file, that contains DART modify sequence

And also common parameters for dartutil tool:

[--outputfile](#outputfile) **optional**

[--dartfilename](#dartfilename) **optional**

[--from](#from) **optional**

[--to](#to) **optional**

[--useFakeNet](#usefakenet) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

## Use cases:
TBD

# generate
```
--generate
```
Generate a fake test dart. Recomended to use with [--useFakeNet](#usefakenet)

## Parameters

[--width](#width) **optional**

[--rings](#rings) **optional**

And also common parameters for dartutil tool:

[--dartfilename](#dartfilename) **optional**

[--from](#from) **optional**

[--to](#to) **optional**

[--useFakeNet](#usefakenet) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

## Use cases
### Case: simple call
```
./dartutil --generate
```
#### Success
**Result:**
```
98%  GENERATED DART. EYE:
```

#### Failure
Possible failure see [--dartfilename](#dartfilename)

# nncupdate
```
--nncupdate
```

Updates existing NetworkNameCard with given name and associated records in DART. Takes name as a parameter.<br>
Before calling `nncupdate` DART file must exist and must contain valid NetworkNameCard with given name and other associated records.<br>
One of the [exclusive functions](#exclusive-functions) 

## Parameters

[--nncupdate](#nncupdate) **required** Function takes string that contains name of NetworkNameRecord to update

[--verbose](#verbose) **optional**

And also common parameters for dartutil tool:

[--dartfilename](#dartfilename) **optional**

[--from](#from) **optional**

[--to](#to) **optional**

[--useFakeNet](#usefakenet) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

Example of using:
```
./dartutil --nncupdate="test name"
./dartutil --nncupdate="test name" -d="dart.drt" --usefakenet --verbose
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

## Parameters

[--nncread](#nncupdate) **required** Function takes string that contains name of NetworkNameRecord to read

[--verbose](#verbose) **optional**

And also common parameters for dartutil tool:

[--dartfilename](#dartfilename) **optional**

[--from](#from) **optional**

[--to](#to) **optional**

[--useFakeNet](#usefakenet) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

Example of using:
```
./dartutil --nncread="test name"
./dartutil --nncread="test name" -d="dart.drt" --usefakenet --verbose
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

## Parameters

[--testaddblocks](#testaddblocks) **required** Function takes number of blocks to add

[--verbose](#verbose) **optional**

And also common parameters for dartutil tool:

[--dartfilename](#dartfilename) **optional**

[--from](#from) **optional**

[--to](#to) **optional**

[--useFakeNet](#usefakenet) **optional**

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

## Parameters

[--testdumpblocks](#testdumpblocks) **required** Function takes number of blocks to dump

[--verbose](#verbose) **optional**

And also common parameters for dartutil tool:

[--dartfilename](#dartfilename) **optional**

[--from](#from) **optional**

[--to](#to) **optional**

[--useFakeNet](#usefakenet) **optional**

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
#### Failure
**Result** (when file not found):<br>
**Refactor** handle exception
```
std.file.FileException@std/file.d(371): : No such file or directory
----------------
??:? [0x562969f0ba35]
??:? [0x562969f34c06]
??:? [0x562969f1511f]
??:? [0x562969ee521c]
...
```

**Result** (when filen has wrong format):<br>
**Refactor** handle exception
```
tagion.hibon.HiBONException.HiBONException@/home/ivanbilan/work/tagion/src/lib-hibon/tagion/hibon/HiBONRecord.d(700): HiBON Document format failed
----------------
??:? [0x5615c716aa35]
??:? [0x5615c7193c06]
??:? [0x5615c717411f]
...
```

# outputfile
```
--outputfile -o
```
Sets the output file name.<br>
Default value: path generated with random seed. Variants of this path:
```
/tmp/deleteme.dmd.unittest.pid277FFE000372B8
/tmp/deleteme.dmd.unittest.pid277FFE000372BC
```
<br><br>
Can be used with any function in dartutil

# from
```
--from
```
Sets _from_ angle for DART.<br>
Acceptable values [0...?]<br>
Values when `from == to` means full.<br>
Default value: `0`
<br><br>
Can be used with any function in dartutil

## Use cases
### Case: value out of range
#### Failure
**Refactor** exception 
```
std.conv.ConvOverflowException@/home/ivanbilan/bin/ldc2-1.28.1-linux-x86_64/bin/../import/std/conv.d(2402): Overflow in integral conversion
----------------
??:? [0x56245008ca35]
??:? [0x5624500b5c06]
??:? [0x56245009611f]
home/ivanbilan/bin/ldc2-1.28.1-linux-x86_64/bin/../import/std/conv.d:2402 [0x56244f637e4e]
home/ivanbilan/bin/ldc2-1.28.1-linux-x86_64/bin/../import/std/conv.d:1970 [0x56244f637cac]
...
```

# to
```
--to
```
Sets _to_ angle for DART.<br>
Values when `from == to` means full.<br>
Default value: `0`
<br><br>
Can be used with any function in dartutil

## Use cases

See [--to](#use-cases-2) use cases.

# useFakeNet
```
--useFakeNet -fn
```
Enables fake hash test-mode<br>
Default value: `False`
<br><br>
Can be used with any function in dartutil

# dump
```
--dump
```
Dumps all the arcvives with in the given angle (see [--from](#from) [--to](#to)).
<br><br>
Can be used with any function in dartutil

# eye
```
--eye
```
Prints the bullseye of DART
<br><br>
Can be used with any function in dartutil

# width
```
--width -w
```
Sets the rings width and is used in combination with [--generate](#generate)<br>
Default value: `4`

# rings
```
--rings
```
Sets the rings height and is used in combination with [--generate](#generate)<br>
Default value: `4`

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
