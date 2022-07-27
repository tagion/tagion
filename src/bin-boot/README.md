<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# tagionboot v.0.x.x
> This tool is used for creating and cusomising recorders.
>- [tagionboot v.0.x.x](#tagionboot-v0xx)
      - [Tool link](#tool-link)
#### [Tool link](https://github.com/tagion/tagion/tree/release/src/bin-boot)

# Table of context
- [tagionboot v.0.x.x](#tagionboot-v0xx)
      - [Tool link](#tool-link)
- [Table of context](#table-of-context)
- [version](#version)
- [output](#output)
  - [Use cases](#use-cases)
    - [Case - set new output filename](#case---set-new-output-filename)
      - [Success](#success)
      - [Failure](#failure)
- [initbills](#initbills)
  - [Parameters](#parameters)
  - [Use cases:](#use-cases-1)
    - [Case - creating dummy bills recorder](#case---creating-dummy-bills-recorder)
      - [Success](#success-1)
      - [Failure](#failure-1)
- [nnc](#nnc)
  - [Parameters](#parameters-1)
  - [Use cases:](#use-cases-2)
    - [Case - creating recorder with name "test"](#case---creating-recorder-with-name-test)
      - [Success](#success-2)
      - [Failure](#failure-2)
      - [Failure](#failure-3)
# version
```
--version
```
Display the tagionboot version
# output
```
--output -o
```
Set new output file for generated recorder with received filename.
Default output name - ./tmp/dart.hibon

## Use cases
### Case - set new output filename
```
tagionboot --output test.hibon
```
#### Success
**Result**
Created test.hibon file with empty recorder

**Refactor** not change default filename, should not generate empty recorder

#### Failure
Result (empty filename)
```
std.getopt.GetOptException@/home/lokalbruger/bin/ldc2-1.29.0-linux-x86_64/bin/../import/std/getopt.d(879): Missing value for argument --output.
```


# initbills
```
--initbills
```
Generate recorder with bills, with next amount [4, 1, 100, 40, 956, 42, 354, 7, 102355]
Used for test purpose only.

## Parameters
--[output](#output) **optional**

## Use cases:
### Case - creating dummy bills recorder
```
tagionboot --initbills
```

#### Success
Created recorder file with bills

**Refactor** should receive number of bills and their amount as parameter or from config file. Must not override file with nnc

#### Failure
**Result** (tmp directory not exists)
**Refactor** handle exception
```
std.file.FileException@std/file.d(836): tmp/dart.hibon: No such file or director
```

# nnc
```
--nnc
```
Initialize NetworkNameCard with given name.
Create hibon file which contains recorder with initialized HashLock, NetworkNameCard and NetworkNameRecord.
As default recorder will be stored in ./tmp/dart.hibon

## Parameters
--[output](#output) **optional**

## Use cases:
### Case - creating recorder with name "test"
```
tagionboot --nnc test
```
#### Success
Created output file which contains recorder named "test"

#### Failure
**Result** (empty name)

**Refactor** handle exception
```
std.getopt.GetOptException@/home/lokalbruger/bin/ldc2-1.29.0-linux-x86_64/bin/../import/std/getopt.d(879): Missing value for argument --nnc.

```
#### Failure
**Result** (tmp directory not exists)
**Refactor** handle exception
```
std.file.FileException@std/file.d(836): tmp/dart.hibon: No such file or director
```

