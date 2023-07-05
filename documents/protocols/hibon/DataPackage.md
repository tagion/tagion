# Data Package

A data package is defined as with a length in bytes appended string of bytes.

| Length field    | Data       |
| --------------- | ---------- |
| unsigned LEB128 | byte array |

The length field is defined by a unsigned [LEB128](/documents/protocols/hibon/HiBON_LEB128.md).


