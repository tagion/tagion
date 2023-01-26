# bin-boot

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
Default output name - /tmp/dart.hibon

## Use cases
### Case - set new output filename
```
./tagionboot --output test.hibon
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
./tagionboot --initbills
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
./tagionboot --nnc test
```
#### Success
Created output file which contains recorder named "test"

#### Failure
**Result** (empty name)

**Refactor** handle exception
```
std.getopt.GetOptException@/home/lokalbruger/bin/ldc2-1.29.0-linux-x86_64/bin/../import/std/getopt.d(879): Missing value for argument --nnc.

```
**Result** (tmp directory not exists)
**Refactor** handle exception
```
std.file.FileException@std/file.d(836): tmp/dart.hibon: No such file or director
```

