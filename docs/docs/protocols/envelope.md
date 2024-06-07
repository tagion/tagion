# Envelope

> Transport container with data compression and checksum validation

## Header

| Offset | Size | Name | Description |
| ------ | ---- | ---- | ----------  |
| 0 | 4 | magic | (ubyte[4]) MagicBytes = 0xDEADBEEF |
| 4 | 4 | schema | (uint) Container version (for future) |
| 8 | 4 | level | (CompressionLevel:uint) ZLIB level: none=0, zlib9=9 |
| 12 | 8 | datsize | (ulong) Data block size |
| 20 | 8 | datsum | (ubyte[8]) Data block checksum |
| 28 | 4 | hdrsum | (ubyte[4]) Header (above 28 bytes) checksum |

## Data

| Offset | Size | Name | Description |
| ------ | ---- | ---- | ----------  |
| 32 | ... | data | (ubyte[]) Data block |
| | | tail | (ubyte[]) Rest of incoming buffer after the end of envelope |
| | | errorstate | (bool) Error state after incoming buffer parsed and validated |
| | | errors | (string[]) Error list after incoming buffer parsed and validated |

## Methods

### Constructor from buffer

` Envelope(ubyte[] buf); ` - try to find first header, validate it, cut the tail and set error status

### Constructor from scratch

` Envelope(uint schema, uint level, ref ubyte[] data); ` - build envelope, compress data if needed and set checksums

### Transport buffer exporter

` toBuffer() ` - returns ubyte[] with whole envelope

### Data extractor

` toData() ` - returns ubute[] with uncompressed data block


