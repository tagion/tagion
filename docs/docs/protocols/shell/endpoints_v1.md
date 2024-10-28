# End Points version 1

`/api/v1/[endpoint]`

## HiRPC endpoints

| Endpoint | Method | Content type | Response type | Description |
| :-------- | :--------: | :--------: | :--------: | :-------- |
| /hirpc/[nocache] | POST | application/octet-stream | application/octet-stream | HiRPC request to be sent to the kernel as-is. Request should be of valid HiRPC receive method. If method is **dartRead** the cache may be used if it is enable in the shell and not *nocache*in path. Method **submit** is deprecated. Method **faucet** is a successor of the */invoice2pay* endpoint.  |
| /dart/[nocache] | POST |  |  | Alias for */hirpc*. Deprecated. |
| /contract | POST |  |  | Alias for */hirpc*. Deprecated.  |
| /invoice2pay | POST  | application/octet-stream | application/octet-stream | This endpoint is for testing/presentation only. Expected the HiBON document with valid invoice to be instantly paid from the default wallet configured in the selected node. The signed contract is created and sent to kernel. Response HiBON is returned. |

## non-HiRPC endpoints

| Endpoint | Method | Content type | Response type | Description |
| :-------- | :--------: | :--------: | :--------: | :-------- |
| /version | GET |  | text/plain | Tagionshell version and build info. |
| /bullseye/[json\|hibon] | GET |  | application/json<br/>application/octet-stream | The DART bullseye in the JSON or HiBON (default) form. |
| /sysinfo | GET |  | application/json | System info of the server where tagon shell is running. Also contains the shell options. |
| /lookup/[method]/[key] | GET |  | application/octet-stream | Search request for the database or record log. Valid **method** : {dart,trt,transaction,record}. Expect the **key** is base64URL string contains the valid public key or search index or whatever be used to create the HiRPC request. Key requirements by method context:<br/><ul><li> **dart**  - Expect the *"@....."* query string to create the DART read request with DARTcrud. String should be base64URL encoded. (yes, twice base64 is not a bug)<li> **trt** - Expect the *"#$Y:\*:@....."* query string to create the TRT read request with DARTcrud. String should be base64URL encoded.<li> **transaction** - not implemented yet<li> **record** - not implemented yet</ul>|
| /util/[subject]/[method]/[data] | GET<br/>POST | application/json<br/>application/octet-stream | application/json<br/>application/octet-stream | Several tools which does not affect the node kernel, just for formatting, conversion or validation. Implemented subjects and methods:<br/><ul><li> subject = **hibon** <ul><li> method = **fromjson** - Expect the application/json POST data and perform HiBONJSON conversion and validation. Returns the binary serialized document.<li> - method = **tojson** - Expect the application/octet-stream POST data or base64URL GET data and perform Document validation. Returns the JSON serialized Document.</ul></ul>|
| /subscribe | GET |  |  | WebSocket endpoint for UPGRADE request. Sends the JSON formatted data stream according to the subscription.<br/>Control command format: _"[subscribe\|unsubscribe]\\0[subject]"_<br/>Subjects: {monitor,recorder,trt} |
