The hirpc tool helps create common tagion HiRPC's.
For more on the HiRPC specification see https://hibon.org/posts/hirpc

```
Documentation: https://docs.tagion.org/

Usage:
hirpc [<option>...]

<option>:
     --version display the version
-v   --verbose Prints more debug information
-o    --output Output filename (Default stdout)
-m    --method method name for the hirpc to generate
-d --dartinput dart inputs sep. by comma or multiple args for multiples generated differently for each cmd
-p     --pkeys pkeys sep. by comma or multiple args for multiple entries
-h      --help This help information.
```

The '--dartinput' flag is used for the dartRead and dartCheckRead methods.  
It takes a list of dartIndices in the same format as the `dartutil --read` flag.  
To better understand the dartIndex and namerecords you can read the [dartindex](https://docs.tagion.org/docs/protocols/dart/dartindex) page.  


The '--method' flag takes a single name argument as the method name, it should be on of the ones described in [Public HiRPC methods](https://docs.tagion.org/docs/protocols/hirpcmethods), and can optionally take `trt.` entity prefix.  


## Sending the requests
The hirpc tool does not do network request it will only output the request to a file.  
For sending the request over a network you can eg. use `curl` or `nngcat` depending on the protocol.  
If using `http`, You can use curl like this
```
curl -X POST -H "Content-Type: application/octet-stream" --data-binary @request.hibon https://localhost:3000/api/v1/hirpc
```

Or if using nng request-reply protocol
```
nngcat --req --dial abstract://NEUEWELLE_DART --file request.hibon
```


## Examples
*Note that the special characters # and $ are escaped '\'. Some shell's may not treat these characters specially and you would not need to escape them*

Create a dartBullseye request and save it to a file.
```
hirpc -m dartBullseye -o bullseye_request.hibon
```

Read a regular dart archive.
```
hirpc -m dartRead -d @SujJFrSfNbTtdbxtSqtapnww-V_rrpktwSJoE0WSPJM=
```

Read the tagion head record.

```sh
hirpc -m dartRead -d \#name:tagion
```

Check that epoch record 13 and 27 has been written to the DART.
```sh
hirpc -m dartCheckRead -d \#\$epoch:i64:13,\#\$epoch:i64:27
```
Or just
```sh
hirpc -m dartCheckRead -d \#\$epoch:i64:13  -d \#\$epoch:i64:27
```


Read a trt archive to get all of the archives associated with a public key.  
The trt archives aren't stored in the main consensus database so they have to be redirected to the `trt.` entity
```sh
hirpc -m trt.dartRead -d \#\$Y:\*:@AoL9_T3JJ09fnPKo7Y1in9mpKkjgxSQ_sD0t0CPCcLKk
```
