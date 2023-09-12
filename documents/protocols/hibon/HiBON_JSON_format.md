# Converting between HiBON and JSON

To secure than HiBON is hash invariant when HiBON is converted back and forth between HiBON and JSON. The JSON must flow the format described below. 

A HiBON object must be generated as a JSON object and a HiBON array must be generated as a JSON object. HiBON data types must be generated as a JSON array with two element where the element index 0  is HiBON type as a string and element index 1 is the contains the value.

Except for HIBON type STRING and BOOLEAN which uses the JSON type directly and the JSON null type is converted to a empty HiBON object.



| Type name | HiBON Type | Type-Code | D-Type        |  Value format    | JSON Type      |
| --------- | ---------- | --------- | ------------- | ---------------- | -------------- |
| "f32"     | FLOAT32    |   0x17    | float         | hex_float        | string         |
| "f64"     | FLOAT64    |   0x18    | double        | hex_float        | string         |
| "i32"     | INT32      |   0x11    | int           | number\|signed   | number\|string |
| "i64"     | INT64      |   0x12    | long          | signed           | string         |
| "u32"     | UINT32     |   0x14    | uint          | number\|unsigend | number\|string |
| "u64"     | UINT64     |   0x15    | ulong         | unsigend         | string         |
|           | BOOLEAN    |   0x08    | bool          | bool             | bool           |
|           | STRING     |   0x01    | string        | string           | string         |
| "time"    | TIME       |   0x09    | sdt_t         | string           | [ISO 8601](https://www.ionos.com/digitalguide/websites/web-development/iso-8601/)  |
| "ibig"    | INTBIG     |   0x1A    | BigNumber     | signed \| base64 | string         |
| "*"       | BINARY     |   0x03    | Buffer        | base64 \|  hex   | string         |
| "ver"     | UINT32     |   0x1F    | uint          | unsigend         | number         |



## Value format

This table shows the valid formats describe as regular expression.

| Value format | Regular expression (in D std.regex syntax)                   |
| ------------ | ------------------------------------------------------------ |
| hex_float    | `[-]?0[xX][0-9a-fA-F]+(\.[0-9a-fA-F]+)[pP][+-]?[0-9a-fA-F]+` |
| signed       | `-?(0[xX][0-9a-fA-F]+|[0-9]+)`                               |
| unsigend     | `(0[xX][0-9a-fA-F]+|[0-9]+)`                                 |
| hex          | `0[xX][0-9a-fA-F]+`                                          |
| base64URL    | `@[A-Za-z0-9\-_\=]+[=]*`                                     |

 

## JSON compliant rules

1. The syntax of the JSON must compile to the JSON standard https://www.json.org/json-en.html
2. If some items in the JSON document does not fit the HiBON to JSON format it is defined as an error.
3. The JSON member name **$VER** is reserved for to fined future HiBON versions.



## JSON compliant tests

Form a converter to be able compliant with HiBON and JSON conversion standard. The convert must be able to convert the flowing.

**Test sample 1**

This examples contains all the types in HiBON as an HiBON object inside and HiBON object.

```json
{
    "BIGINT": [
        "big",
        "@meiC-oiHr6Tg-POQtYdZ"
    ],
    "BOOLEAN": true,
    "FLOAT32": [
        "f32",
        "0x1.3ae148p+0"
    ],
    "FLOAT64": [
        "f64",
        "0x1.9b5d96fe285c6p+664"
    ],
    "INT32": [
        "i32",
        -42
    ],
    "INT64": [
        "i64",
        "0xfffb9d923e586d5a"
    ],
    "UINT32": [
        "i32",
        42
    ],
    "UINT64": [
        "i64",
        "0x4626dc1a792a6"
    ],
    "sub_hibon": {
        "BINARY": [
            "*",
            "@AQIDBA=="
        ],
        "STRING": "Text",
        "TIME": [
            "time",
            "2023-09-06T15:10:31.354119"
        ]
    }
}
```

HiBON as hex dump of the binary data 

```
00000000  a4 01 1a 06 42 49 47 49  4e 54 99 e8 82 fa 88 87  |....BIGINT......|
00000010  af a4 e0 f8 f3 90 b5 87  59 08 07 42 4f 4f 4c 45  |........Y..BOOLE|
00000020  41 4e 01 17 07 46 4c 4f  41 54 33 32 a4 70 9d 3f  |AN...FLOAT32.p.?|
00000030  18 07 46 4c 4f 41 54 36  34 c6 85 e2 6f d9 b5 79  |..FLOAT64...o..y|
00000040  69 11 05 49 4e 54 33 32  56 12 05 49 4e 54 36 34  |i..INT32V..INT64|
00000050  da da e1 f2 a3 b2 e7 7d  14 06 55 49 4e 54 33 32  |.......}..UINT32|
00000060  2a 15 06 55 49 4e 54 36  34 a6 a5 9e 8d dc cd 98  |*..UINT64.......|
00000070  02 02 09 73 75 62 5f 68  69 62 6f 6e 29 03 06 42  |...sub_hibon)..B|
00000080  49 4e 41 52 59 04 01 02  03 04 01 06 53 54 52 49  |INARY.......STRI|
00000090  4e 47 04 54 65 78 74 09  04 54 49 4d 45 c3 f9 d7  |NG.Text..TIME...|
000000a0  87 c2 d5 ec ed 08                                 |......|
```

**Test sample 2**

Same value as test sample 1 except that index is use to store data.

Note. Because the inner object is name "sub_hibon" the main HiBON is defined as an object.

```json
[
    "big",
        "@meiC-oiHr6Tg-POQtYdZ"
    ],
    true,
    [
        "f32",
        "0x1.3ae148p+0"
    ],
    [
        "f64",
        "0x1.9b5d96fe285c6p+664"
    ],
    [
        "i32",
        -42
    ],
    [
        "i64",
        "0xfffb9d923e586d5a"
    ],
    [
        "u32",
        42
    ],
    [
        "u64",
        "0x4626dc1a792a6"
    ],
    [
        [
            "*",
            "@AQIDBA=="
        ],
        "Text",
        [
            "time",
            "2023-09-11T12:47:36.0169725"
        ]
    ]
]
```

HiBON daya are shown as hex dump of the binary data 

```
00000000  66 1a 00 00 99 e8 82 fa  88 87 af a4 e0 f8 f3 90  |f...............|
00000010  b5 87 59 08 00 01 01 17  00 02 a4 70 9d 3f 18 00  |..Y........p.?..|
00000020  03 c6 85 e2 6f d9 b5 79  69 11 00 04 56 12 00 05  |....o..yi...V...|
00000030  da da e1 f2 a3 b2 e7 7d  14 00 06 2a 15 00 07 a6  |.......}...*....|
00000040  a5 9e 8d dc cd 98 02 02  00 08 1c 03 00 00 04 01  |................|
00000050  02 03 04 01 00 01 04 54  65 78 74 09 00 02 fd 85  |.......Text.....|
00000060  d8 87 c2 d5 ec ed 08                              |.......|
```


