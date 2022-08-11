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
- [version](#version)
- [dartfilename](#dartfilename)
  - [Use cases](#use-cases-3)
    - [Success](#success-4)
    - [Failure](#failure-4)
    - [Failure](#failure-5)
- [initialize](#initialize)
- [inputfile](#inputfile)
  - [Use cases](#use-cases-4)
    - [Case: simple call](#case-simple-call)
      - [Success](#success-5)
      - [Failure](#failure-6)
- [outputfile](#outputfile)
- [dump](#dump)
  - [Use cases](#use-cases-5)
    - [Case: dump DART](#case-dump-dart)
- [eye](#eye)
  - [Use cases](#use-cases-6)
    - [Case: print bullseye](#case-print-bullseye)
- [passphrase](#passphrase)
- [verbose](#verbose)

## Exclusive functions
You can call only one function from this list at a time
- [--read](#read)
- [--rim](#rim)
- [--modify](#modify)
- [--rpc](#rpc)
  
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
Hash should contain only characters allowed for hex numbers (digits [0..9] and letters [a..f] or [A..F]) and separator character '_'. Length of string hash should be even (ignoring separator characters).

Example of using:
```
./dartutil -r 1ef4e838_a9aa1a80_dcc2a3af_4fd57190_f8a91c3b_373c8514_2f294168_7ebf127f

./dartutil -r 1ef4e838 -r 5d07e4bf -r 7d6c4450
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
Result has been written to '/tmp/deleteme.dmd.unittest.pid467287FFCBD44164C'
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
Result has been written to '/tmp/deleteme.dmd.unittest.pid467287FFCBD44164C'
Document: {
    "result": {
        "$@": "Recorder"
    }
}
```

**Result** (when hash has wrong character)<br>
```
Error parsing hash string: Bad char 'G'. Abort
```

**Result** (when hash has wrong length)<br>
```
Error parsing hash string: Hex string length not even. Abort
```

### Case: read several records
```
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 5d07e4bfff14a719e0b4e57dc76bfa330ffe173c9da28afa279c337a39e171d9 7d6c44500ae8d95d4287ab56cc15c85c5ddceba715648889c991b1732847ad0f --verbose
```
#### Success
**Result** <br>
Found records with given hashes. Single recorder with all records is written to outputfile and console:
```
Result has been written to '/tmp/deleteme.dmd.unittest.pid1546947FFF383A799C'
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
        },
        "1": {
            "$a": {
                "$@": "HL",
                "$lock": [
                    "*",
                    "@iL02\/dq84CuR8hWuxy2urTu6yMPf1lHfIK2hilgjpxY="
                ]
            },
            "$t": [
                "i32",
                1
            ]
        },
        "2": {
            "$a": {
                "$@": "$epoch0",
                "$actives": {},
                "$epoch": [
                    "i32",
                    0
                ],
                "$global": [
                    "*",
                    "@"
                ],
                "$prev": [
                    "*",
                    "@AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
                ],
                "$recorder": [
                    "*",
                    "@"
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
**Result** (when some but not all hashes found)<br>
Found some records with some given hashes. Single recorder with all found records is written to outputfile and console:
```
Result has been written to '/tmp/deleteme.dmd.unittest.pid1556907FFD5989C18C'
Document: {
    "result": {
        "$@": "Recorder",
        "0": {
            "$a": {
                "$@": "HL",
                "$lock": [
                    "*",
                    "@iL02\/dq84CuR8hWuxy2urTu6yMPf1lHfIK2hilgjpxY="
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
Result has been written to '/tmp/deleteme.dmd.unittest.pid467287FFCBD44164C'
Document: {
    "result": {
        "$@": "Recorder"
    }
}
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

```
Error trying to modify: HiBON Document format failed. Abort
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

Tool stops working
```
Fail to open DART: Cannot open file `/tmp/default.drt' in mode `r+' (No such file or directory). Abort.
```
**Note**: DART file can be created using [--initialize](#initialize)

### Failure
**Result** (when DART file have wrong format):

Tool stops working
```
Fail to open DART: BlockFile should be sized in equal number of blocks of the size of 64 but the size is 578. Abort.
```

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
--verbose
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
