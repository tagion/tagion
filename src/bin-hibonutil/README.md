<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# Tagion 0.9.0 release
>Hibonutil utility for text/json binary object notation files

#### [Tool link](https://github.com/tagion/tagion)

# Table of contents
- [Tool link](#tool-link)
- [Table of contents](#table-of-contents)
- [just name file](#just name file)
  - [Description](#description)
  - [Use cases](#use-cases)
    - [Case 1](#case-1)
      - [Success](#success)
      - [Failure](#failure)
    - [Case 2](#case-2)
      - [Success](#success-1)
- [bin](#bin)
  - [Description](#Description)
- [help](#help)
  - [Description](#Description)
- [outputfile](#outputfile)
  - [Description](#Description)
- [pretty](#pretty)
  - [Description](#Description).
- [value](#value)
  - [Description](#Description)
- [version](#version)
  - [Description](#Description)

# just name file

## Description
Simple comand line parameter - path to hibon/json file
Example of using:
```
/folder/file.hibon
```

## Use cases
_Brief description of both correct and error use cases_

### Case 1
```
tmp.hibon
```
#### Success
**Result**:
<br>Open hibon and show representation
<br>_Below the console output after this scenario_
```
{
    key:value
}
```
#### Failure
**Result** (when path not exists):
<br>show crash exception
##### brief : maybe need rewrite behavior for fail cases
**Result** (when path has inappropriate format):
<br>Show unredable parse out
##### brief : maybe need rewrite behavior for fail cases

### Case 2
```
file.ext
```
#### Success
**Result**:
<br>message about unssuported extensio
<br>_Below the console output after this scenario_
```
File file.ext not valid (only .hibon .json)
```
# bin
```
-b --bin
```
## Description
Not work yet

# help
```
-h --help
```
## Description
Show a short command list with basic description

# outputfile
```
-o --outputfile
```
## Description
Write program out to json-represented file file
Example of using:
```
--outputfile outfile.json
```

# pretty
```
-p --pretty
```
Example of using:
```
--pretty readfile.hibon
```
## Description
Print formatted JSON representation of hibon file

# value
```
-V --value
```
## Description
Not work yet

# version
```
--version
```
## Description
Not work yet