# envelope

> Envelope is a tool for pack/unpack envelope containers from files or streams

## Options
```
Usage:
envelope [<option>...] 

<option>:
         --version display the version
-v       --verbose Prints verbose information to console
-i          --info Prints incoming envelope metadata and exit
-p          --pack Force pack incoming buffer to envelope
-u        --unpack Force unpack incoming envelope end export data buffer
-f          --file Filename to read data from (instead of stdin)
-o           --out Sets the output file name (instead of stdout)
-b     --blocksize Chunk size to split large buffers when pack
-s        --schema Schema to use when pack
-c      --compress Compression level to use when pack [0..9]
-h          --help This help information.sage:

```

## Examples

### Create uncompressed envelope from hibon file and send it to network socket

```sh
    envelope -p -s 1 -c 0 -f file.hibon | nc -N 192.168.1.1:8080
```

### Chunk the network stream th the chunked envelopes and send to another socket

```sh
    nc -l -p 8080 | envelope -p -s 1 -c 7 -b 262144 | nc -N 192.168.1.1:8080
```

### Unpack the envelope and save it to file

```sh
    envelope -u -f data.bin -o file.hibon
```


