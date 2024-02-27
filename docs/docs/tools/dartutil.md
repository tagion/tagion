# dartutil ( DART database util )

> Dartutil is tool read/inspect and manimulate the data store in a DART file (.drt)

## Options
```
Usage:
dartutil [<option>...] file.drt <files>

Example synchronizing src.drt on to dst.drt
dartutil --sync src.drt dst.drt

<option>:
         --version display the version
-v       --verbose Prints verbose information to console
             --dry Dry-run this will not save the wallet
-I    --initialize Create a dart file
-o    --outputfile Sets the output file name
-r          --read Excutes a DART read sequency
             --rim Performs DART rim read
-m        --modify Excutes a DART modify sequency
             --rpc Excutes a HiPRC on the DART
           --strip Strips the dart-recoder dumps archives
-f         --force Force erase and create journal and destination DART
           --print prints all the archives with in the given angle
            --dump Dumps all the archives with in the given angle
   --dump-branches Dumps all the archives and branches with in the given angle
             --eye Prints the bullseye
            --sync Synchronize src.drt to dest.drt
-e          --exec Execute string to be used for remote access
-P    --passphrase Passphrase of the keypair : default: verysecret
-A         --angle Sets angle range from:to (Default is full range)
           --depth Set limit on dart rim depth
            --fake Use fakenet instead of real hashes : default :false
-h          --help This help information.sage:
dartutil [<option>...] file.drt <files>

```

## Create an empty dart
```
dartutil --initialize database.drt
```
The DART can also be created with to use the fake hash with the  `--fake` option.

## Display an inspect the DART file
The .drt file is a block-file so thei [blockutil](/docs/tools/blockutil) can also be used to inspect the file.

#### The bullseye of the DART can be display with the `--eye` switch.
```
dartutil genesis.drt --eye
EYE: 2069c3e00c031294ae45945d45fa20e0f0f09e036ca1153bb66da94d9bc369a8artutil 
```
#### The DART map can be listed with the `--print` switch.
```
dartutil genesis.drt --print
EYE: 2069C3E00C031294AE45945D45FA20E0F0F09E036CA1153BB66DA94D9BC369A8
| 04 [3]
| .. | 62 [2]
| .. | .. 046274d40b1eff9e71841a89993ddb8ecd239fb8daabafac8899b768577be172 [1]
| 11 [6]
| .. | 75 [5]
| .. | .. 11753b22fc264c9479d1c5dc895211524ebf1b7872833db9363095f4a47c176c [4] #
| 1B [9]
| .. | 2A [8]
| .. | .. 1b2a5ae6ba6101826e0aeebcd517dd6c75e94562a0a17ca4c6647d4b3a5cb55e [7] #
| 27 [12]
| .. | 56 [11]
| .. | .. 27569ae10bf14338809efaafd51657e20c716e0aa381ab2386d03a7a2fc15516 [10] #
| 33 [15]
| .. | C5 [14]
| .. | .. 33c5338e20ae3409042fbf11990ebeb54670d92ecfe254c5e4f52f8e1694adaa [13] #
| 36 [18]
| .. | 2D [17]
| .. | .. 362d3cbab4e6f1f7624c0c95adc9874fb00af0a9b2a06a1f0d87a474497120f4 [16]
| 38 [21]
.... continued
```

The numbers in `[number]` is the blockfile index (in decimal) which can be read via the [blockutil](docs/tools/blockutil).

The rim-key are shown as `| XX` and rim-key (in hexadecimal).

The `--angle` selects the angle range and `--depth` selects the rim depth in the DART.

The long hexadecimal number is the dart-index of the archive.

The `#` at the end of the dart-index indicates that the archive is a dart-key.

#### If the DART is big the map print out can be limited with the `--angle` and `--depth`.



```
dartutil genesis.drt --angle C034:C670 --print --depth 3
EYE: 2069C3E00C031294AE45945D45FA20E0F0F09E036CA1153BB66DA94D9BC369A8
| C0 [66]
| .. | 34 [65]
| .. | .. c034d68fe76c4ca96315e44fc0bac330e56ee46a68b11cb49877af9073dfabf9 [64]
| C6 [69]
| .. | 53 [68]
| .. | .. c653fcf92e4bc1ccf4e41acd85876f62a1e2422a1fe7d849b65cd8e75cf298c3 [67]
```

## Read an inspect data in the DART.

In the following section it's shown how information can be read out of the DART.

#### Raw data can be read out of the DART with the `--dump`

The data read out is stream out as a *HiBON* stream and by default is stream to `stdout`.
The output can be redirected via the `-o filename.hibon` switch.

```
dartutil genesis.drt --angle C034:C670 --dump --depth 3|hibonutil -pc
{
    "$@": "TGN",
    "$V": {
        "$": [
            "i64",
            "0xde0b6b3a7640000"
        ]
    },
    "$Y": [
        "*",
        "@A6MNNwTp0c88kgIvkVSGve_GQOmu1lgdTMrVH_8RsLQQ"
    ],
    "$t": [
        "time",
        "2023-12-04T16:09:33.1522481"
    ],
    "$x": [
        "*",
        "@0kD6FQ=="
    ]
}
{
    "$@": "TGN",
    "$V": {
        "$": [
            "i64",
            "0xde0b6b3a7640000"
        ]
    },
    "$Y": [
        "*",
        "@ApvreSMnipDHPVrz2YprVc63hGqpLsidQ0c-eT5VXAvS"
    ],
    "$t": [
        "time",
        "2023-12-04T16:10:35.4239432"
    ],
    "$x": [
        "*",
        "@pZtmng=="
    ]
}
```
With the `--dump-branches` the branches in the DART are also streamed.
```
dartutil genesis.drt --angle 1175:1B2A --dump-branches --depth 3 |hibonutil -pc 
{
    "$@": "$@B",
    "$idx": {
        "113": [
            "u64",
            "0x27"
        ],
        "152": [
            "u64",
            "0x2a"
...
---- cut
...
 {
    "$@": "$@B",
    "$idx": {
        "89": [
            "u64",
            "0x63"
        ]
    },
    "$prints": {
        "89": [
            "*",
            "@tUpjU37nzEYfttwiGSYQcb4lCuq0uh8q5f-15julbJw="
        ]
    }
}
```

#### The rim-path can be selected via `--rim` switch

By default the `--rim` returns the `HiRPC` response (rim-path as hex-string).

The rim-path can also be set in decimal by separating the number with a comman.

```
dartutil genesis.drt --rim C034 |hibonutil -pc
{
    "$@": "HiRPC",
    "$Y": [
        "*",
        "@Av2fcgwMGh3blxvHL9mnVz81SZ9AC_-zVhNK1MD2Asea"
    ],
    "$msg": {
        "result": {
            "$@": "$@B",
            "$prints": {
                "214": [
                    "*",
                    "@wDTWj-dsTKljFeRPwLrDMOVu5GposRy0mHevkHPfq_k="
                ]
            }
        }
    },
    "$sign": [
        "*",
        "@tPZjBvIi1qIXulGf2z__REIHJHrH6N4PDABQwbtJVzO9ZowylrSJxnOrO6WVRTJRJ1skeS3K9jGQ0EUpVBo4dg=="
    ]
}
```
`Note. Select the same rim-path with decimal rim keys.`
```
dartutil genesis.drt --rim 192,52, |hibonutil -pc

```

The `HiRPC` encapsulation can be stripped with the `--strip` switch.
```
dartutil genesis.drt --rim 1175 --strip |hibonutil -pc

```



## DART Crud commands
You can call only one of the CRUD command at a time
- [--read](#read)
- [--rim](#rim)
- [--modify](#modify)
- [--rpc](#rpc)
  
# read
```
--read -r
```
Reads records from DART by hash. Can take several hashes at once.  
DART file must exist before calling.


One of the [exclusive functions](#exclusive-functions) 


This function requires value. Takes one or several strings which are hashes in DART database.
Hash should contain only characters allowed for hex numbers (digits [0..9] and letters [a..f] or [A..F]) and separator character '_'. Length of string hash should be even (ignoring separator characters).

Example of using:
```
./dartutil -r 1ef4e838_a9aa1a80_dcc2a3af_4fd57190_f8a91c3b_373c8514_2f294168_7ebf127f

./dartutil -r 1ef4e838 -r 5d07e4bf -r 7d6c4450

# Read a owner hash key from the trt dart
./dartutil -r\#\$Y:\*:@AhsxFPQykU33A7TjcBWMZZkql1IqGq0mUoPXjbxrEO6I trt.drt 
```

## Parameters

[--verbose](#verbose) **optional**

[--outputfile](#outputfile) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

## Use cases:
### Case: read single record
```
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 --verbose
```
#### Success
**Result**  

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
**Result** (when record not found)  

Empty recorder is written to outputfile and console
```
Result has been written to '/tmp/deleteme.dmd.unittest.pid467287FFCBD44164C'
Document: {
    "result": {
        "$@": "Recorder"
    }
}
```

**Result** (when hash has wrong character)  

```
Error parsing hash string: Bad char 'G'. Abort
```

**Result** (when hash has wrong length)  

```
Error parsing hash string: Hex string length not even. Abort
```

### Case: read several records
```
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 5d07e4bfff14a719e0b4e57dc76bfa330ffe173c9da28afa279c337a39e171d9 7d6c44500ae8d95d4287ab56cc15c85c5ddceba715648889c991b1732847ad0f --verbose
```
#### Success

**Result**  

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


**Result** (when some but not all hashes found)  

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

**Result** (when record not found)  

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

Executes a DART modify sequency from HiBON file.  

DART file must exist before calling, but can be created instantly using [--initialize](#initialize)  

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

**Result**  

Created new DART file. Executed sequence from file. Result is written to outputfile.  

No console output.

#### Failure

**Result** (input file has wrong format):  

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

**Result**  

Opened DART file. Executed sequence from input file. Result is written to outputfile.  
No console output.

#### Failure

See [previous case](#case-create-new-dart-with-executed-sequence-from-file) failures.

Also see [--dartfilename](#dartfilename) and [--inputfile](#inputfile) for possible failures of this case.


See also use cases of parameters, used in this function

# rpc

```
--rpc
```

Executes a HiPRC on the DART.  

DART file must exist before calling, but can be created instantly using [--initialize](#initialize)  



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

Sets the dartfile.

Default value: `/tmp/default.drt`  



Can be used with any function in dartutil

## Use cases
```
./dartutil <function> [implicit -d=default]
./dartutil <function> -d="dart.drt"
```
### Success

**Result**:  

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

Creates a new DART file.



Can be used as independed function or in combination with [exclusive functions](#exclusive-functions).

# inputfile

```
--inputfile -i
```

Sets the HiBON input file name.  



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

file at the specified path was opened.


No console output

#### Failure

**Result** (when file not found):

Tool stop working
```
Can't open input file 'tmp.txt'. Abort
```

# outputfile

```
--outputfile -o
```

Sets the output file name.  

Output file could have any extension. Dartutil writes output in HiBON format.  

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

Passphrase of the keypair when creating net. Takes text string.  
Default value: `"verysecret"`
    
Can be used with any function in dartutil

# verbose
```
--verbose
```
Boolean flag, that enables more detailed output to console  
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
