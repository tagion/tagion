
subscriber is a simple tool to subscribe to events published by tagionwave

```
Help information for subscriber

-v --version Print revision information
-o  --output Output filename; if empty stdout is used
-f  --format Set the output format default: pretty, available [pretty, json, hibon]
   --address Specify the address to subscribe to
       --tag Specify tags to subscribe to
  --contract Subscribe to status of a specific contract (base64url hash)
-h    --help This help information.
```

## Examples

**Subscribe to all contracts events**

```bash
subscriber --contract
```

*Sample Output*

```bash
> @XK_D0XOPU0Z2_Jo-j2lSEbHK5W-Ip0fqec8KiOBpIPc= 1 | Verified
> @MxDfet7e5Ns1oI9uhxety4SuMglyJ5RdGQ6Tn7bee-c= 0 | Rejected
```


**Subscribing to a specific contract**

You can show the outputs of specific contracts only 
by providing the hash of the [SignedContract](/docs/protocols/contract#signed-contractssc) in base64url.

:::tip
base64url hash of a HiBON can be shown with `hibonutil -tHc`  
Make sure you are getting the hash of the SignedContract and not the HiRPC
:::

```bash
subscriber --contract=@XK_D0XOPU0Z2_Jo-j2lSEbHK5W-Ip0fqec8KiOBpIPc=
```

*Sample Output*
```bash
> @XK_D0XOPU0Z2_Jo-j2lSEbHK5W-Ip0fqec8KiOBpIPc= 1 | Verified
> @XK_D0XOPU0Z2_Jo-j2lSEbHK5W-Ip0fqec8KiOBpIPc= 2 | Input Valid
> @XK_D0XOPU0Z2_Jo-j2lSEbHK5W-Ip0fqec8KiOBpIPc= 3 | Signed
> @XK_D0XOPU0Z2_Jo-j2lSEbHK5W-Ip0fqec8KiOBpIPc= 4 | Produced
```
