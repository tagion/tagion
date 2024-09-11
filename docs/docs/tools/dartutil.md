# dartutil

> Dartutil is tool read/inspect and manipulate the data stored in a DART file (.drt)

## Options
```
Documentation: https://docs.tagion.org/

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
-r          --read Executes a DART read sequency
             --rim Performs DART rim read
-m        --modify Executes a DART modify sequency
             --rpc Executes a HiPRC on the DART
           --print Prints all the dartindex with in the given angle
            --dump Dumps all the archives with in the given angle
   --dump-branches Dumps all the archives and branches with in the given angle
             --eye Prints the bullseye
            --sync Synchronize src.drt to dest.drt
-A         --angle Sets angle range from..to (Default is full range)
           --depth Set limit on dart rim depth
            --fake Use fakenet instead of real hashes : default :false
            --test Generate a test dart with specified number of archives total:bundle
    --flat-disable Disable flat branch hash
-h          --help This help information.
```

## Examples

### Create an empty dart

```sh
dartutil --initialize database.drt
```

The DART can also be created with to use the fake hash with the  `--fake` option.

**Display an inspect the DART file**
The .drt file is a block-file so the [blockutil](/docs/tools/blockutil) can also be used to inspect the file.

**The bullseye of the DART can be display with the `--eye` switch.**  

```sh
dartutil genesis.drt --eye
```
Example of a bullseye.
```sh
EYE: 2069c3e00c031294ae45945d45fa20e0f0f09e036ca1153bb66da94d9bc369a8artutil 
```

**The DART map can be listed with the `--print` switch.**  

```sh
dartutil genesis.drt --print
```
Sample output.
```sh
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

The numbers in `[number]` is the blockfile index (in decimal) which can be read via the [blockutil](/docs/tools/blockutil).

The rim-key are shown as `| XX` and rim-key (in hexadecimal).

The `--angle` selects the angle range and `--depth` selects the rim depth in the DART.

The long hexadecimal number is the dart-index of the archive.

The `#` at the end of the dart-index indicates that the archive is a dart-key.

**If the DART is big the map print out can be limited with the `--angle` and `--depth`.**


```sh
dartutil genesis.drt --angle C034..C670 --print --depth 3
```
Sample output
```sh
EYE: 2069C3E00C031294AE45945D45FA20E0F0F09E036CA1153BB66DA94D9BC369A8
| C0 [66]
| .. | 34 [65]
| .. | .. c034d68fe76c4ca96315e44fc0bac330e56ee46a68b11cb49877af9073dfabf9 [64]
| C6 [69]
| .. | 53 [68]
| .. | .. c653fcf92e4bc1ccf4e41acd85876f62a1e2422a1fe7d849b65cd8e75cf298c3 [67]
```

### Read and inspect data in the DART.

In the following section it's shown how information can be read out of the DART.

*Raw data can be read out of the DART with the `--dump`*

The data read out is stream out as a *HiBON* stream and by default is stream to `stdout`.
The output can be redirected via the `-o filename.hibon` switch.

```
dartutil genesis.drt --angle C034..C670 --dump --depth 3|hibonutil -pc
```
Prints this to the stdout.
```json
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

```sh
dartutil genesis.drt --angle 1175..1B2A --dump-branches --depth 3 |hibonutil -pc
```
Prints this to stdout
```json
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

**The rim-path can be selected via `--rim` switch**

By default the `--rim` returns the `HiRPC` response (rim-path as hex-string).

The rim-path can also be set in decimal by separating the number with a command.

```sh
dartutil genesis.drt --rim C034 | hibonutil -pc
```
Prints this to the stdout.
```json
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

```sh
dartutil genesis.drt --rim 192,52, |hibonutil -pc

```

The `HiRPC` response can be stripped with via the `hirpc` command.

```sh
dartutil genesis.drt --rim 1175 |hiprc -R |hibonutil -pc

```

Change the stdout to a file.

```sh
dartutil genesis.drt --rim 1175 -o response.hibon 

```

## Generate a test database
A test database containing random data can be generated with.
```sh
dartutil -I test.drt
dartutil --test 10000:1000 test.drt
```
This will generate 10000 archives with 1000 archives in each recorder.

## Synchronize two data base files.
The following command will synchronizing test.drt to test1.drt
```sh
dartutil --sync test.drt test1.drt

```
The synchronizing will first generate list of journal files which will be replaced in the second phase.


## Example of reading data in a rim

First a slice if DART is selected to list the fingerprints of the archives.
```sh
dartutil test.drt --print --angle AEDA..AEF4
```
The `--print` switch will print a list of the dart-indices in the angle range `[AEDA..AEF4[`.
```sh
| AE [40836]
| .. | DA [26939]
| .. | .. aeda1f49efc1a6a45481391df36aa64b2ad57409b4910f904480b42d2b823a5e [16412]
| .. | E0 [22529]
| .. | .. aee0a47cd2558f36222f3407d9af1d34016b1542276fdca122513b17cf6c5d30 [20211]
| .. | E6 [16915]
| .. | .. aee637b4a31d0decc43682bac53c55cec17ec85a8b236c94f4808291b56eebbc [16914]
| .. | E7 [16913]
| .. | .. aee74bb146b27920d0e548391f552717ca00959fab172d8b0d72e0f9ab6b4dc9 [29193]
| .. | .. aee7cd1f669dec45f1df82195d0212c610bc1bf8a84c53dad7b6e31613734a61 [13915]
| .. | E9 [16442]
| .. | .. aee906caf1375710482c66a60f918db326d39b48e4d35d4c3c06f279bfdc7598 [16441]
| .. | EC [37722]
| .. | .. aeec9c6dbbfa3be1d9f71644522309e640ba05ac123dfe946245a907763f83be [18198]
| .. | F2 [16908]
| .. | .. aef2d4ac9930bf673d42f117c8e6f2fde6d3b66fff492598f012bc094d4bbb73 [16894]
```
For the print out it can be seen that at the rim-path `AEE7` contain two archive.
```sh
dartutil test.drt --rim aee7 | hibonutil -pc
```
This will print out the `HiRPC` response from the database.
```json
{
    "$@": "HiRPC",
    "$Y": [
        "*",
        "@A2D7p10zvvwbzCWZVwp8AJeiZmc1ck7Tb-8uEaXP3q2u"
    ],
    "$msg": {
        "result": {
            "$@": "$@B",
            "$prints": {
                "205": [
                    "*",
                    "@rufNH2ad7EXx34IZXQISxhC8G_ioTFPa17bjFhNzSmE="
                ],
                "75": [
                    "*",
                    "@rudLsUayeSDQ5Ug5H1UnF8oAlZ-rFy2LDXLg-atrTck="
                ]
            }
        }
    },
    "$sign": [
        "*",
        "@RfVzQjiSYAvJU5QnTOzpAOUe4zlhe8Gp_wlYBy3qb5Tl6UJ-fT5CjMcqORpFw8pmRQYeXFvDldGzk3lCM7EYeQ=="
    ]
}
```
The result can be filter out with the `hirpc -R` command.
```sh 
dartutil test.drt --rim aee7 | hirpc -R | hibonutil -pc
```
This will list the branch at rim-path `aee7`.
```json
{
    "$@": "$@B",
    "$prints": {
        "205": [
            "*",
            "@rufNH2ad7EXx34IZXQISxhC8G_ioTFPa17bjFhNzSmE="
        ],
        "75": [
            "*",
            "@rudLsUayeSDQ5Ug5H1UnF8oAlZ-rFy2LDXLg-atrTck="
        ]
    }
}
```
To read the two archives in this can be done with.
```sh 
 dartutil test1.drt -r @rufNH2ad7EXx34IZXQISxhC8G_ioTFPa17bjFhNzSmE=  -r @rudLsUayeSDQ5Ug5H1UnF8oAlZ-rFy2LDXLg-atrTck= |hirpc -R|hibonutil -pc
```
This will print the recoder containing the two dart-indices
```json
{
    "$@": "Recorder",
    "0": {
        "$T": [
            "i32",
            1
        ],
        "$a": {
            "text": "Test document 16290047585690276710"
        }
    },
    "1": {
        "$T": [
            "i32",
            1
        ],
        "$a": {
            "text": "Test document 6198624785561080932"
        }
    }
}
```
The two archives can be copied to another database by the following.
```sh
 dartutil -I slice_test.drt
 dartutil test1.drt -r @rufNH2ad7EXx34IZXQISxhC8G_ioTFPa17bjFhNzSmE=  -r @rudLsUayeSDQ5Ug5H1UnF8oAlZ-rFy2LDXLg-atrTck= |hirpc -R > recoder.hibon
 dartutil slice_test.drt -m recoder.hibon 

```
Check that the two archives has been copied.
```sh
 dartutil slice_test.drt --print
```
Print this to the stdout.
```sh
EYE: 6DD2A52F5543892095524D41F7A1A33AF030E510AB779F775D0FCB88B7DD9518
| AE [4]
| .. | E7 [3]
| .. | .. aee74bb146b27920d0e548391f552717ca00959fab172d8b0d72e0f9ab6b4dc9 [1]
| .. | .. aee7cd1f669dec45f1df82195d0212c610bc1bf8a84c53dad7b6e31613734a61 [2]
```

## DART Crud commands
You can call only one of the CRUD command at a time
- [--read](#read)
- [--rim](#rim)
- [--modify](#modify)
- [--eye](#eye)
- [--rpc](#rpc)
  
### read

```
--read -r
```

Reads records from DART by hash. Can take several hashes at once.  
DART file must exist before calling.


This function requires value. Takes one or several strings which are hashes in DART database.
Hash should contain only characters allowed for hex numbers (digits [0..9] and letters [a..f] or [A..F]) and separator character '_'. Length of string hash should be even (ignoring separator characters).

Example of using:

```
./dartutil -r 1ef4e838_a9aa1a80_dcc2a3af_4fd57190_f8a91c3b_373c8514_2f294168_7ebf127f

./dartutil -r 1ef4e838 -r 5d07e4bf -r 7d6c4450

#Read a owner hash key from the trt dart
./dartutil -r\#\$Y:\*:@AhsxFPQykU33A7TjcBWMZZkql1IqGq0mUoPXjbxrEO6I trt.drt 
```

Read the tagion head record
```
dartutil -r\#name:tagion Node_0_dart.drt
```

**Parameters**

[--verbose](#verbose) **optional**

[--outputfile](#outputfile) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**


**Use cases:**  
*Case: read single record*  
```
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 --verbose
```

**Success**  

*Result*  

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

**Failure**

*Result* (when record not found)  

Empty recorder is written to outputfile and console
```
Result has been written to '/tmp/deleteme.dmd.unittest.pid467287FFCBD44164C'
Document: {
    "result": {
        "$@": "Recorder"
    }
}
```

*Result* (when hash has wrong character)  

```
Error parsing hash string: Bad char 'G'. Abort
```

*Result* (when hash has wrong length)  

```
Error parsing hash string: Hex string length not even. Abort
```

*Case: read several records*  
```
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 5d07e4bfff14a719e0b4e57dc76bfa330ffe173c9da28afa279c337a39e171d9 7d6c44500ae8d95d4287ab56cc15c85c5ddceba715648889c991b1732847ad0f --verbose
```
**Success**  

*Result*  

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


*Result* (when some but not all hashes found)  

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

**Failure**  

*Result* (when record not found)  

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

### rim
```
--rim
```
**Refactor** need to implement

### modify
```
--modify -m
```

Executes a DART modify sequency from HiBON file.  

DART file must exist before calling, but can be created instantly using [--initialize](#initialize)  

**Parameters**

[--inputfile](#inputfile) **required** HiBON file, that contains DART modify sequence

[--outputfile](#outputfile) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**

**Use cases:**  
*Case: create new DART with executed sequence from file*  

```
./dartutil --initialize -m -i="tmp.hibon"
```

**Success**  

*Result*  

Created new DART file. Executed sequence from file. Result is written to outputfile.  

No console output.

**Failure**

*Result* (input file has wrong format):  

Created new DART file. No DART sequence executed. Aborted.

```
Error trying to modify: HiBON Document format failed. Abort
```

Also see [--outputfile](#outputfile) and [--inputfile](#inputfile) for possible failures of this case.

**Case: execute sequence on existent DART**

```
./dartutil -m -i="tmp.hibon"
```

**Success**

*Result*  

Opened DART file. Executed sequence from input file. Result is written to outputfile.  
No console output.

**Failure**

Also see [--outputfile](#outputfile[--inputfile](#inputfile) for possible failures of this case.

See also use cases of parameters, used in this function

### eye

```
--eye
```

Prints the bullseye of DART.
Can be used with any function in dartutil

**Use cases**  
*Case: print bullseye*

```
./dartutil --eye
```

**Result**

```
EYE: 29a444af19221a7ed3dbb6e459a946745feace5a300a5390c2e48b6b27047d3d
```

### rpc

```
--rpc
```

Executes a HiPRC on the DART.  

DART file must exist before calling, but can be created instantly using [--initialize](#initialize)  


**Parameters**  

[--inputfile](#inputfile) **required** HiBON file, that contains DART modify sequence

[--outputfile](#outputfile) **optional**

[--dump](#dump) **optional**

[--eye](#eye) **optional**

[--passphrase](#passphrase) **optional**


## Other switches

### version

```
--version -v
```

Displays the version of tool


### initialize

```
--initialize
```

Creates a new DART file.

### inputfile

```
--inputfile -i
```

Sets the HiBON input file name.  

Used in:
- [--rpc](#rpc)
- [--modify](#modify)

**Use cases**
*Case: simple call*

```
./dartutil <function> -i "tmp.txt"
```

**Success**

*Result*:

file at the specified path was opened.


No console output

**Failure**

*Result* (when file not found):

Tool stop working
```
Can't open input file 'tmp.txt'. Abort
```

### outputfile

```
--outputfile -o
```

Sets the output file name.  

Output file could have any extension. Dartutil writes output in HiBON format.  

To open output file using `hibonutil` it should have extension `.hibon`.

Default value: path generated with random seed. Variants of this path:
```
/tmp/deleteme.dmd.unittest.pid277FFE000372B8
/tmp/deleteme.dmd.unittest.pid277FFE000372BC
```

Can be used with any function in dartutil

### dump

```
--dump
```

Dumps all the archives from DART.
    
Can be used with any function in dartutil

**Use cases**  
*Case: dump DART*  

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


### passphrase

```
--passphrase -P
```

Passphrase of the keypair when creating net. Takes text string.  
Default value: `"verysecret"`
    
Can be used with any function in dartutil


### verbose

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

*Result:* no output to console  
*With verbose*

```sh
./dartutil -r 1ef4e838a9aa1a80dcc2a3af4fd57190f8a91c3bf373c85142f2941687ebf127 --verbose
```

*Result:*  

```json
{
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
