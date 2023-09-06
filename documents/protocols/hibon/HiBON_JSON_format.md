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
| "time"    | TIME       |   0x09    | sdt_t         | unsigend         | string         |
| "ibig"    | INTBIG     |   0x1A    | BigNumber     | signed \| base64 | string         |
| "*"       | BINARY     |   0x03    | Buffer        | base64 \|  hex   | string         |
| "ver"     | UINT32     |   0x1F    | uint          | unsigend         | numnber        |



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
        "@g0qwRVSuRUr6sTLA48YXAAE="
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
        "0xfedccba987654321"
    ],
    "TIME": [
        "sdt",
        "0x3e9"
    ],
    "UINT32": [
        "u32",
        42
    ],
    "UINT64": [
        "u64",
        "0x1233456789abcdf"
    ],
    "sub_hibon": {
        "BINARY": [
            "*",
            "@AQID"
        ],
       "STRING": "Text"
    }
}
```

HiBON data as array of byte values

```d
[207, 1, 27, 6, 66, 73, 71, 73, 78, 84, 17, 131, 74, 176, 69, 84, 174, 69, 74, 250, 177, 50, 192, 227, 198, 23, 0, 1, 8, 7, 66, 79, 79, 76, 69, 65, 78, 1, 33, 7, 70, 76, 79, 65, 84, 51, 50, 164, 112, 157, 63, 1, 7, 70, 76, 79, 65, 84, 54, 52, 198, 133, 226, 111, 217, 181, 121, 105, 16, 5, 73, 78, 84, 51, 50, 86, 18, 5, 73, 78, 84, 54, 52, 161, 134, 149, 187, 152, 245, 178, 238, 126, 9, 4, 84, 73, 77, 69, 233, 7, 32, 6, 85, 73, 78, 84, 51, 50, 42, 34, 6, 85, 73, 78, 84, 54, 52, 223, 249, 234, 196, 231, 138, 205, 145, 1, 3, 9, 115, 117, 98, 95, 104, 105, 98, 111, 110, 71, 5, 6, 66, 73, 78, 65, 82, 89, 3, 1, 2, 3, 31, 10, 67, 82, 69, 68, 69, 78, 84, 73, 65, 76, 4, 117, 9, 10, 11, 6, 8, 67, 82, 89, 80, 84, 68, 79, 67, 4, 42, 6, 7, 8, 35, 7, 72, 65, 83, 72, 68, 79, 67, 4, 27, 3, 4, 5, 2, 6, 83, 84, 82, 73, 78, 71, 4, 84, 101, 120, 116];
```

**Test sample 2**

Same value as test sample 1 except that index is use to store data.

Note. Because the inner object is name "sub_hibon" the main HiBON is defined as an object.

```json
{
    "0": [
        "f32",
        "0x1.3ae148p+0"
    ],
    "1": [
        "f64",
        "0x1.9b5d96fe285c6p+664"
    ],
    "2": true,
    "3": [
        "i32",
        -42
    ],
    "4": [
        "i64",
        "0xfedccba987654321"
    ],
    "5": [
        "u32",
        42
    ],
    "6": [
        "u64",
        "0x1233456789abcdf"
    ],
    "7": [
        "big",
        "@g0qwRVSuRUr6sTLA48YXAAE="
    ],
    "8": [
        "sdt",
        "0x3e9"
    ],
    "sub_hibon": [
        [
            "*",
            "@AQID"
        ],
        "Text",
   ]
}
```

HiBON data are shown as array of byte values

```d
[131, 1, 33, 0, 0, 164, 112, 157, 63, 1, 0, 1, 198, 133, 226, 111, 217, 181, 121, 105, 8, 0, 2, 1, 16, 0, 3, 86, 18, 0, 4, 161, 134, 149, 187, 152, 245, 178, 238, 126, 32, 0, 5, 42, 34, 0, 6, 223, 249, 234, 196, 231, 138, 205, 145, 1, 27, 0, 7, 17, 131, 74, 176, 69, 84, 174, 69, 74, 250, 177, 50, 192, 227, 198, 23, 0, 1, 9, 0, 8, 233, 7, 3, 9, 115, 117, 98, 95, 104, 105, 98, 111, 110, 39, 5, 0, 0, 3, 1, 2, 3, 2, 0, 1, 4, 84, 101, 120, 116, 35, 0, 2, 4, 27, 3, 4, 5, 31, 0, 3, 4, 117, 9, 10, 11, 6, 0, 4, 4, 42, 6, 7, 8];
```

**Test sample 3**

Same value as test sample 1 and 2 except that is all stored in array.

```json
[
    [
        "f32",
        "0x1.3ae148p+0"
    ],
    [
        "f64",
        "0x1.9b5d96fe285c6p+664"
    ],
    true,
    [
        "i32",
        -42
    ],
    [
        "i64",
        "0xfedccba987654321"
    ],
    [
        "u32",
        42
    ],
    [
        "u64",
        "0x1233456789abcdf"
    ],
    [
        "big",
        "@g0qwRVSuRUr6sTLA48YXAAE="
    ],
    [
        "sdt",
        "0x3e9"
    ],
    [
        [
            "*",
            "@AQID"
        ],
        "Text",
        [
            "#",
            "@GwMEBQ=="
        ],
        [
            "&",
            "@dQkKCw=="
        ],
        [
            "(#)",
            "@KgYHCA=="
        ]
    ]
]
```

HiBON data as array of byte values

```d
[123, 33, 0, 0, 164, 112, 157, 63, 1, 0, 1, 198, 133, 226, 111, 217, 181, 121, 105, 8, 0, 2, 1, 16, 0, 3, 86, 18, 0, 4, 161, 134, 149, 187, 152, 245, 178, 238, 126, 32, 0, 5, 42, 34, 0, 6, 223, 249, 234, 196, 231, 138, 205, 145, 1, 27, 0, 7, 17, 131, 74, 176, 69, 84, 174, 69, 74, 250, 177, 50, 192, 227, 198, 23, 0, 1, 9, 0, 8, 233, 7, 3, 0, 9, 39, 5, 0, 0, 3, 1, 2, 3, 2, 0, 1, 4, 84, 101, 120, 116, 35, 0, 2, 4, 27, 3, 4, 5, 31, 0, 3, 4, 117, 9, 10, 11, 6, 0, 4, 4, 42, 6, 7, 8];
```



