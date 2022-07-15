<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# dartutil v.0.1.0
> This tool is used for working with local DART database. It allows to read and modify directly and also can run some test scenarios in DART structure.
>
#### [Tool link](https://github.com/tagion/tagion/tree/release/src/bin-dartutil)

# Table of contents
- [dartutil v.0.1.0](#dartutil-v010)
      - [Tool link](#tool-link)
- [Table of contents](#table-of-contents)
  - [Exclusive functions](#exclusive-functions)
- [read](#read)
- [rim](#rim)
- [modify](#modify)
- [rpc](#rpc)
- [generate](#generate)
- [nncupdate](#nncupdate)
  - [Parameters](#parameters)
  - [Use cases](#use-cases)
    - [Case: simple call](#case-simple-call)
      - [Success](#success)
      - [Failure](#failure)
- [nncread](#nncread)
  - [Parameters](#parameters-1)
  - [Use cases](#use-cases-1)
    - [Case: simple call](#case-simple-call-1)
      - [Success](#success-1)
      - [Failure](#failure-1)
- [testaddblocks](#testaddblocks)
- [testdumpblocks](#testdumpblocks)
- [version](#version)
- [dartfilename](#dartfilename)
  - [Use cases](#use-cases-2)
    - [Success](#success-2)
    - [Failure](#failure-2)
- [initialize](#initialize)
- [inputfile](#inputfile)
  - [Use cases](#use-cases-3)
    - [Case: simple call](#case-simple-call-2)
      - [Failure](#failure-3)
- [outputfile](#outputfile)
- [from](#from)
  - [Use cases](#use-cases-4)
    - [Case: value out of range](#case-value-out-of-range)
      - [Failure](#failure-4)
- [to](#to)
  - [Use cases](#use-cases-5)
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
TBD

# rim
TBD

# modify
TBD

# rpc
TBD

# generate
TBD

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
--nncupdate="test name"
--nncupdate="test name" -d="dart.drt" --usefakenet --verbose
```

## Use cases

### Case: simple call 
```
--nncupdate="test name"
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
--nncread="test name"
--nncread="test name" -d="dart.drt" --usefakenet --verbose
```

## Use cases

### Case: simple call 
```
--nncread="test name"
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
TDB
# testdumpblocks
TDB

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
<function> [implicit -d=default]
<function> -d="dart.drt"
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
