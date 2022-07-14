<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# dartutil v.0.1.0
> This tool is used for working with local DART database. It allows to read and modify directly and also can run some test scenarios in DART structure.
>
#### [Tool link](https://github.com/tagion/tagion/tree/release/src/bin-dartutil)
# Table of contents
- [dartutil v.0.1.0](#dartutil-v010)
      - [Tool link](#tool-link)
- [Table of contents](#table-of-contents)
- [read](#read)
- [rim](#rim)
- [modify](#modify)
- [rpc](#rpc)
- [generate](#generate)
- [nncupdate](#nncupdate)
  - [Description](#description)
  - [Parameters](#parameters)
  - [Use cases](#use-cases)
    - [Case 1](#case-1)
      - [Success](#success)
      - [Failure](#failure)
- [nncread](#nncread)
- [testaddblocks](#testaddblocks)
- [testdumpblocks](#testdumpblocks)
- [version](#version)
- [dartfilename](#dartfilename)
  - [Use cases](#use-cases-1)
    - [Success](#success-1)
    - [Failure](#failure-1)
- [initialize](#initialize)
- [inputfile](#inputfile)
- [outputfile](#outputfile)
- [from](#from)
- [to](#to)
- [useFakeNet](#usefakenet)
- [dump](#dump)
- [eye](#eye)
- [width](#width)
- [rings](#rings)
- [passphrase](#passphrase)
- [verbose](#verbose)


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

## Description

Updates existing NetworkNameCard with given name and associated records in DART. Takes name as a parameter.<br>
Before calling `nncupdate` DART file must exist and must contain valid NetworkNameCard with given name and other associated records.<br>
Can't be called with [--read](#read), [--rim](#rim), [--modify](#modify), [--rpc](#rpc), [--nncread](#nncread), [--testaddblocks](#testaddblocks) and [--testdumpblocks](#testdumpblocks) at the same time.<br>

## Parameters

[--nncupdate](#nncupdate) **required** Function takes string that contains name of NetworkNameRecord to update

[--verbose](#verbose) **optional** See argument description

And also common parameters for dartutil tool:

[--dartfilename](#dartfilename) **optional**

[--from](#from) **optional**

[--to](#to) **optional**

[--usefakenet](#usefakenet) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

Example of using:
```
--nncupdate="test name"
--nncupdate="test name" -d="dart.drt" --usefakenet --verbose
```

## Use cases

### Case 1 
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
TDB
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
Default value `/tmp/default.drt`
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
```
std.exception.ErrnoException@std/stdio.d(758): Cannot open file `dart.drt' in mode `r+' (No such file or directory)
----------------
??:? [0x5613ca716a35]
??:? [0x5613ca73fc06]
??:? [0x5613ca72011f]
...exception output...
```

# initialize
TBD
# inputfile
TBD
# outputfile
TBD
# from
TBD
# to
TBD
# useFakeNet
TBD
# dump
TBD
# eye
TBD
# width
TBD
# rings
TBD
# passphrase
TBD
# verbose
TBD