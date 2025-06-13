# TRT

Sometimes you may need to find data in the DART without knowing where it is ie. you don't have the dartindex.
This could eg. be that someone makes a transaction to you, but they don't tell you the dartindex of the output bill.

The trt is the 'transaction-reverse-table'. It is a separate dart database, but there is no consensus on it.
And it is completely optional for a node to maintain it. Since it is a dart all the same methods are allowed as regular dart.
They can be accessed by adding the `trt` domain to a dart method eg. reading an archive from the trt would simply call the `trt.dartRead` method.

Currently 2 different types of lookups are added to the trt. 

One record for getting all the documents owned by a public key

```json
{
    "$@": "$@trt"
    "#$Y": { "type": "*", "description": "The public key to lookup" },
    "indices": { "type": "*[]", "description": "The dart indices" },
}
```

And one to see when a contract was executed.

```json
{
    "$@": "$@trt_contract"
    "#contract": { "type": "*", "description": "The hash of the contract that was sent" },
    "contract": { "type": "document",  "description": "The original contract document" },
    "epoch": { "type": "i64", "description": "The epoch at which the contract was executed" },
}
```
