# DART Index

A DART index is what is used to reference an archive in the DART.  
Eg. when making a dartRead operation you would provide a list of dart Indices and the DART will respond with all of the archives which existed.

A DART index is simply the sha256 hash of the entire serialized Document with the exception of so called hashkeys. Where it is then the hash of the hashkey and the value

The code which implements the function to calculate the DARTIndex is in `tagion.dart.DARTBasic`

```d reference
https://github.com/tagion/tagion/blob/master/src/lib-dart/tagion/dart/DARTBasic.d#L39-L58
```

## DART Namerecords / hashkeys

A Namerecord is a system which provides DNS like name lookup in the DART.

A Namerecord is any HiBON Document with a hashkey as a member.
A hashkey is any member key beginning with a `#`.
Due to HiBON's ordering rules. the hashkey will always be the first element in the document.


# DARTIndex string format
Namerecords allow us to look up specific archives in the database based on partial information from the archive. Therefore a string format is created in order to ease the creation of these indices. The format is specified by:

```
NAME:TYPE:VALUE
```

Where:

`NAME` is the identifier for the namerecord / hashkey. 
`TYPE` is the input type for the value inserted. The types supported and names corresponds to the [HIBONJSON](https://www.hibon.org/posts/hibonjson/) type identifiers.
`VALUE` is the value that needs to be looked up. If the namerecord / hashkey does not require a value for lookup, the TYPE and VALUE do not have to be supplied. 

:::info
Remember to escape characters if using your terminal such as `* # $`
:::

| Lookup type       | String dartindex                                      |
| ----------------- | ----------------------------------------------------- |
| Normal dartindex  | `@6iG4DIYzyL9PESxI16486uofvkUhYUPP7JxG8Bq18zI=`       |
| Tagion head       | `#name:tagion`                                        |
| Epoch 47          | `#$epoch:i64:47`                                      |
| TRT pubkey archive| `#$Y:*:@A9bVIut4seaNAu16AC5MLx2rgUBzL5tKW0TBk_G_rPVY` |
