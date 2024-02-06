# HiBON report tool `hirep`


> This tool filter from a HiBON-stream 
 The *herep* support the following arguments.
 ```
Documentation: https://tagion.org/

Usage:
hirep [<option>...] [<hibon-file>]

<option>:
      --version display the version
-v    --verbose Prints more debug information
-o     --output Output file name (Default stdout)
-n       --name HiBON member name (name as text or regex as `regex`)
-r --recordtype HiBON recordtype (name as text or regex as `regex`)
-t       --type HiBON data types
          --not Filter out match
-l       --list List of indices in a hibon stream (ex. 1,10,20..23)
-h       --help This help information.
```

If no hibon-file are given then the *HiBON* is read from stdin and if output file is not given with `-o` switch then the output is witten directly to stdout.

## Filter functions

Three filter functions can be given to the *hirep*.

- `-r` filter by recordtype
- `-t` filter by HiBON type.
- `-n` filter by HiBON name.

Ex. dump all dart-indices in DART with an owner `$Y` by combining the *dartutil* and the *hibonutil*

```
dartutil Node_0_dart.drt --dump|hirep -n\$Y |hibonutil -cDt
@AuRKHG2glc-tPP9kIyQE27__PvGc4dq1qabsNmy42m8=
@BGJ01Ase_55xhBqJmT3bjs0jn7jaq6-siJm3aFd74XI=
....
@8nXU56yTxOiah06OjEB8NSw8e2y3tNhOGI5ol254O-c=
@-cJfZFp8_pQO3a8oauW396lLuxrjZAK-iyaQN-afgbo=
@_ZH0FqzrLbPzTtYovNeLtcQH79Lb9UB5pz1umyRiFgA=
```

Ex. dump all fingerprints in DART with the record-type `$@E`.
```
dartutil Node_0_dart.drt --dump|hirep -r\$\@\E |hibonutil -cHt
@JRubbKZ3K6uVlf8ljdeT7hdzWCJH36_2sUBw5Wms7To=
@rSpACNqG3S5gUWD5eBl4reAZPQjjg7VBr9XqA6DsgPs=
@xX8iKWzhnsB9m0UDWmHwOjiNusY-WKipQEMB1rpdDsM=
@y68eB_MhoLaFLM0nPeGU92F9smxjZxgcY88_00DbHGQ=
@A6UlfGYIZa2_94RYPcocMnWKIju_TghUPk-jXqLb4-0=
....
```

Ex. dump all fingerprints in DART with the member name `$V` and the hibon-type `i64`.
```
blockutil ~/tmp/prod_node/wave/Node_0_dart.drt --dump|hirep -n\$V -t i64 |hibonutil -cHt
@AuRKHG2glc-tPP9kIyQE27__PvGc4dq1qabsNmy42m8=
@BGJ01Ase_55xhBqJmT3bjs0jn7jaq6-siJm3aFd74XI=
@Cri1PSAAg26dc3x7B3cxgrBiDCxfAq2rc_sZQBg2N6Q=
@D46pOfNBWZc8ulbABnfYN8_tTbXmAVcm5fy269g0HMo=
@JeBI6m6mHM0KgNNGHKzuJVstEcLya106YvDai2so4D0=
@LJ00XAsgqK5xa9A0uuYOFOj-p5Uj2h4YS7kAUs44W_0=
@Ni08urTm8fdiTAyVrcmHT7AK8KmyoGofDYekdElxIPQ=
@OGEvFNbElCyNbtpKQUfcyp_D6d72o-U15JHUz56UrvI=
@OR82Mj-13DKKb9meo6vqNjVv-6mAjTS7NS6mvdtG3Ak=
@QOGv_iHxxxGwAIZGEGhWD3UP3xxQtDoodKQ_vUYMkHA=
@QehkoOLywoGDTdb1w2ld0zURC9F9rK7pga9MckM4pC0=
@T0LPApUT1Ml-SlAobsBs-zrUHyxXhCpK3TDb0kQ7FyM=
```

## Select specific hibon indices in the HiBON-stream

The `-l` will select the indices in the hibon-stream.

Ex. select indices (7,100..102) in a replicator stream.
```
hirep 0000200000_epoch.hibon -l7,100..102|hibonutil -pDt
@EHXhFrCJiFFli7eeoMUCT2ESdhEDMH7LkxOjlzqQXM0=
@6N-14VlktCMS6zELF3Ak62v8Cj1AC2B3UK7GNvlij1k=
@m5XCfqonHoqpGSb79aUyXfOdRqslTLgyBFKU_x04LAo=
```
