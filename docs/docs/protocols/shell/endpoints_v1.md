# End Points version 1

`/api/v1/[endpoint]`

## HiRPC endpoints

| Endpoint | Method | Content type | Response type | Description |
| :-------- | :--------: | :--------: | :--------: | :-------- |
| /hirpc/[nocache] | POST | application/octet-stream | application/octet-stream | HiRPC request to be sent to the kernel as-is. Request should be of valid HiRPC receive method. If method is _dartRead_ the cache may be used if it is enable in the shell and not *nocache*in path. Method _submit_ is deprecated. Method _faucet_ is a successor of the */invoice2pay* endpoint.  |
| /dart/[nocache] |  |  |  | Alias for */hirpc*. Deprecated. |
| /contract |  |  |  | Alias for */hirpc*. Deprecated.  |
| /invoice2pay | POST  | application/octet-stream | application/octet-stream | This endpoint is for testing/presentation only. Expected the HiBON document with valid invoice to be instantly payed from the default wallet configured in the selected node. The signed contract is created and sent to kernel. Response HiBON is returned. |

## non-HiRPC endpoints

| Endpoint | Method | Content type | Response type | Description |
| :-------- | :--------: | :--------: | :--------: | :-------- |
| /version | GET |  | text/plain | Tagionshell version and build info. |
| /bullseye/[json\|hibon] | GET |  | application/json<br/>application/octet-stream | The DART bullseye in the JSON or HiBON (default) form. |
| /sysinfo | GET |  | application/json | System info of the server where tagon shell is running. Also contains the shell options. |
| /lookup/[method]/[key] | GET |  | application/octet-stream | Search request for the database or record log. Valid _method_ : {dart,trt,transaction,record}. Expect the _key_ is base64URL string contains the valid public key or search index or whatever be used to create the HiRPC request. Key requirements by method context:\
* _dart_  - Expect the *"@....."* query string to create the DART read request with DARTcrud. String should be base64URL encoded. (yes, twice base64 is not a bug)
* _trt_ - Expect the *"#$Y:\*:@....."* query string to create the TRT read request with DARTcrud. String should be base64URL encoded.
* _transaction_ - not implemented yet
* _record_ - not implemented yet
|
| /util/[subject]/[method]/[data] | GET<br/>POST | application/json<br/>application/octet-stream | application/json<br/>application/octet-stream | Several tools which does not affect the node kernel, just for formatting, conversion or validation. Implemented subjects and methods:\
* subject = _hibon_ 
    - method = _fromjson_ - Expect the application/json POST data and perform HiBONJSON conversion and validation. Returns the binary serialized document.
    - method = _tojson_ - Expect the application/octet-stream POST data or base64URL GET data and perform Document validation. Returns the JSON serialized Document.
|

