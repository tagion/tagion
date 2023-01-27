# bin-hibonutil

>Hibonutil console viewer/converter for hibon/json files.

# inputfile
Takes list of  .json and .hibon files.
```
hibonutil inputfile1.hibon inputfile2.json 
```
The `inputfile1.hibon` will be converted to a json output
and the `inputfile1.json` will be converted into a hibon output.
## Parameters
[--pretty](#pretty) or
[--stdout](#stdout) **optional**
## Use cases

###  Case: open file with key
```
hibonutil inputfile.hibon
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
produces an output file `inputfile.hibon` in hibon format

#### Failure
[See](#failure)


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
Pretty formatted out a file `device.json` or to the console with [-c](#stdout) switch

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
# stdout
```
-c --stdout
```
Prints file to the standard output instead a file<br>

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

Example of using:
```
hibonutil --version
```
###  Case: show version
#### Success case
```
version 1.9
```
