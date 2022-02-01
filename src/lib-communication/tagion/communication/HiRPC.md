# Hash-BSON Remote Procedure Call (HPRC)

HRPC is a RPC which can including digital signatures and it is base on HBSON data format.

## Structure of HRPC
```javascipt
{
    $type : 'HPRC',
    $sign : <bin>, // Optional
    $pkey  : <bin>, // Optional
    $msg : {
        id : <uint>,
        method : <string>,
        params : <any HBSON type>,
    }
}
```
The member **sign** is the $sign **hrpc** object and **$pkey** is the public-key which also include a $sign schema code in the genetic package.

### Succes full result
```javascipt
{
    $type : 'HRPC',
    $sign : <bin>,
    $pkey : <bin>,
    $msg : {
        id : <uint>,
        result : <any HBSON type>
    }
}

```

### Failure result
```javascipt
{
    $type : HRPC,
    $sign : <bin>,
    $pkey : <bin>,
    $msg : {
        id : <uint>,
        error : {
            code : <uint>,
            message : <string>
        }
    }
}
```
### Failure result with data object
```javascipt
{
    $type : HRPC,
    $sign : <bin>,
    $pkey : <bin>,
    $msg : {
        id : <uint>,
        error : {
            code : <uint>,
            message : <string>
            data : <DOCUMENT or ARRAY> // Optional
        }
    }
}
```
