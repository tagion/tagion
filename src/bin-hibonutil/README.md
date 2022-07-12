<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# Tagion 0.9.0 release
>Hibonutil utility for text/json binary object notation files

#### [Tool link](https://github.com/tagion/tagion)

# Table of contents
- [Tool link](#tool-link)
- [Table of contents](#table-of-contents)
- [Inputfile](#Inputfile)
  - [Description](#Description)
- [bin](#bin)
  - [Description](#Description)
- [help](#help)
  - [Description](#Description)
- [outputfile](#outputfile)
  - [Description](#Description)
- [pretty](#pretty)
  - [Description](#Description)
- [value](#value)
  - [Description](#Description)
- [version](#version)
  - [Description](#Description)

# Inputfile

## Description
Simple comand line parameter - path to hibon/json file

## Raw inputfile
```
hibonutil inputfile.hibon
```
<br>Open hibon and show in JSON format
```
{"$@":"Quiz","$Q":["What is your favorite book?","What is the name of the road you grew up on?","What is your mother’s maiden name?","What was the name of your first\/current\/favorite pet?"]}
```
## [Pretty inputfile](#pretty)
```
hibonutil -p inputfile.hibon
```
## Description
<br>Open hibon and show in pretty JSON format
```
{
    "$@": "Quiz",
    "$Q": [
        "What is your favorite book?",
        "What is the name of the road you grew up on?",
        "What is your mother’s maiden name?",
        "What was the name of your first\/current\/favorite pet?"
    ]
}
```

## -i inputfile.hibon
```
-i  --inputfile
```
## Description
Force mark file as readable - help if more command line parameters and need mark file how need to open
```
hibonutil -i inputfile.hibon
```
<br>Open hibon and show in JSON format
```
{"$@":"Quiz","$Q":["What is your favorite book?","What is the name of the road you grew up on?","What is your mother’s maiden name?","What was the name of your first\/current\/favorite pet?"]}
```

### Failure
**Result** (when path not exists):
<br>Show crash exception
```
std.file.FileException@std/file.d(370): invalid.hibon: No such file or director
```
#### WIP : need to rewrite invalid cases
**Result** (when path has inappropriate format):
<br>Show unredable parse out

#### WIP : need to rewrite behavior for fail cases
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
WIP

# help
```
-h --help
```
## Description
```
hibonutil -h
```
Show a short command list with basic description

```
Documentation: https://tagion.org/

Usage:
hibonutil [<option>...] <in-file> <out-file>
hibonutil [<option>...] <in-file>

Where:
<in-file>           Is an input file in .json or .hibon format
<out-file>          Is an output file in .json or .hibon format
                    stdout is used of the output is not specifed the

<option>:
      --version display the version
-i  --inputfile Sets the HiBON input file name
-o --outputfile Sets the output file name
-b        --bin Use HiBON or else use JSON
-V      --value Bill value : default: 1000000000
-p     --pretty JSON Pretty print: Default: false
-h       --help This help information.
```

# outputfile
```
-o --outputfile
```
## Description
Write program out to json-represented file file
Example of using:
```
hibonutil --outputfile outfile.json
```

# pretty
```
-p --pretty
```

## Description
Print formatted JSON representation of hibon file
Example of using:
```
hibonutil --pretty readfile.hibon
```

# value
```
-V --value
```
## Description
WIP

# version
```
--version
```
## Description
WIP
