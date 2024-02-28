# hibonutil


> This tool converts to and from HiBON
 The `hibonutil` support the following arguments.
 ```
 Documentation: https://tagion.org/

Usage:
hibonutil [<option>...] <in-file>

Where:
<in-file>           Is an input file in .json or .hibon format

<option>:
   --version display the version
-c  --stdout Print to standard output
-p  --pretty JSON Pretty print: Default: false
-b  --base64 Convert to base64 string
-v --verbose Print more debug information
-o  --output outputfilename only for stdin
    --sample Produce a sample HiBON
-h    --help This help information.
 ```

## HiBON sample

The `hibonutil` can produce sample HiBON files.
```bash
> hibonutil --sample
Write sample.hibon
Write sample_array.hibon
```

This produces two samples files.

## Covert to a JSON format
By default `hibonutil` will convert a `.hibon` file to a `.json` file.
```
> hibonutil sample.hibon

```
Will produces a `sample.json` which can be seen in [HiBON_JSON_format](https://hibon.org/posts/hibonjson).

The json can be printed to stdout with the `-c` and if `-p` is added the in pretty prints the `.json`.
```
> hibonutil -pc sample.hibon
```

## Covert a JSON to HiBON format
By default `hibonutil` will convert a `.json` file to a `.json` file. 
```
> hibonutil sample.json
```
Will produces a `sample.hibon` file.

## Convert to base64.
By adding the `-b` switch the file will be converted to a base64 and this will produces a `.txt` file.

```
> hibonutil -b sample.hibon
```
Convert to base64 to `.hibon`

```
> hibonutil sample.txt
```

## Convert from stdin

The util can read from stdin by specifing a file name with the `-o` switch.

Convert from `.hibon` to `.json`
```
> cat sample.hibon |hibonutil -po test.json
```

## Coverting a list of files
The `hibonutil` can convert a list of file from `.hibon` to `.json` and vica versa.

```
hibonutil sample.json sample_array.hibon test.json
```
Produces the files `sample.hibon sample_array.json test.hibon`.


