<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# Tagion 0.9.0 release
>Hibonutil console viewer/converter for hibon/json files.
#### [Tool link](https://github.com/tagion/tagion)
- [Tagion 0.9.0 release](#tagion-090-release)
      - [Tool link](#tool-link)
- [inputfile](#inputfile)
  - [Parameters](#parameters)
  - [Use cases](#use-cases)
    - [Case: open file with key](#case-open-file-with-key)
      - [Success](#success)
      - [Failure](#failure)
    - [Case: open file](#case-open-file)
      - [Success](#success-1)
      - [Failure](#failure-1)
- [outputfile](#outputfile)
  - [Parameters](#parameters-1)
  - [Use cases](#use-cases-1)
    - [Case: convert file](#case-convert-file)
      - [Success](#success-2)
      - [Failure](#failure-2)
- [pretty](#pretty)
  - [Use cases](#use-cases-2)
    - [Case: open file](#case-open-file-1)
      - [Success case](#success-case)
      - [Failure](#failure-3)
- [version](#version)
    - [Case: show version](#case-show-version)
      - [Success case](#success-case-1)

# inputfile
```
-i  --inputfile
```
Force mark file as readable - help if more command line parameters and need mark file how need to open (support only json/hibon files)
In case with absent any keys - single path be marked as for read
```
hibonutil -i inputfile.hibon
```
## Parameters
[--pretty](#pretty) **optional**

## Use cases

###  Case: open file with key
```
hibonutil --inputfile inputfile.hibon
```
#### Success
**Result**:
<br>Open hibon and show in JSON format
```
{"$@":"Quiz","$Q":["What is your favorite book?","What is the name of the road you grew up on?","What is your mother’s maiden name?","What was the name of your first\/current\/favorite pet?"]}
```
**Result**
<br>Open JSON and show as JSON formatted digits array
```
[0, 1, 2, 3, 4]
```

#### Failure
**Result** (when path not exists):
<br>Show message
```
File inputfile.hibon not found
```

**WIP : need to rewrite invalid cases**
**Result** (when path has inappropriate format):
<br>Show unredable parse out (only hibon)
<br>Json parsing fail example
```
Conversion error, please validate input JSON file
```

**WIP : need to rewrite behavior for fail cases**
**Result**:
<br>message about unssuported extension
<br>_Below the console output after this scenario_
```
File file.ext not valid (only .hibon .json)
```

###  Case: open file
```
hibonutil inputfile.json
```
#### Success
**Result**:
```
[17, 1, 7, 112, 97, 121, 109, 101, 110, 116, 7, 112, 97, 121, 109, 101, 110, 116]
```
#### Failure
[See](#failure)

# outputfile
```
-o --outputfile
```
Write program out to mirored format file, json->hibon or hibon->json.<br>
Example of using:
```
hibonutil --outputfile outfile.json --inputfile inputfile.hibon
```
## Parameters
[--pretty](#pretty) **optional** Only for JSON out files

## Use cases

###  Case: convert file
```
hibonutil --outputfile outfile.json --inputfile inputfile.hibon
```
#### Success
**Result**
<br>Creating new converted file

#### Failure
**Result** (wrong file extension)
```
File inputfile.txt not valid (only .hibon .json)
```
**Result** (absent file)
```
File inputfile.hibon not found
```
**Result** (can not write out to file)
```
outfile.json: No such file or directory
```

# pretty
```
-p --pretty
```
Print formatted JSON representation of hibon file<br>
Example of using:
```
hibonutil --pretty readfile.hibon
```
## Use cases

###  Case: open file
```
hibonutil --pretty device.hibon
```
#### Success case
**Result**:
<br>Pretty formatted out to console
```
{
    "$@": "PIN",
    "D": [
        "*",
        "@7U7QoIF1ZQmqrvORgmtPZ999GY\/BG2OYSHwBVmazVoA="
    ],
    "S": [
        "*",
        "@PdicCrlKiSa3PxSPvS7afez29cFEITBBhIkgOjHg8cA="
    ],
    "U": [
        "*",
        "@REX8BY4i3gGJEtf184WDib6xddd423nBSrzDHqUdbkc="
    ]
}
```

#### Failure
**Result** (wrong file extension)
```
File device.txt not valid (only .hibon .json)
```
**Result** (absent file)<br>
```
File inputfile.hibon not found
```
**Result** (wrong file structure)<br>
Dump of wrong data structures or JSON parsing error [see](#failure)

# version
```
--version
```
Show actual ersion of util.<br>
Example of using:
```
hibonutil --version
```
###  Case: show version
#### Success case
```
version 1.9
```