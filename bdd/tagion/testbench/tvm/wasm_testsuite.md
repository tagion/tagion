## Feature: Test of the wasm to betterc execution
This feature test of transpiler from wasm to betterC parses of the testsuite.
Specified in [WebAssembly testsuite](https://github.com/WebAssembly/testsuite)

`tagion.testbench.tvm.wasm_testsuite`

### Scenario: should converts #wast-file testsuite to wasm file format

`ShouldConvertswastfileTestsuiteToWasmFileFormat`

*Given* a wast testsuite file

`file`

*When* the wast file has successfully been converted to WebAssembly

`webAssembly`

*Then* write the wasm-binary data of to a #wasm-file

`wasmfile`


### Scenario: should load a #wasm-file and convert it into betterC

`ShouldLoadAwasmfileAndConvertItIntoBetterC`

*Given* the testsuite file in #wasm-file format

`wasmfileFormat`

*Then* convert the #wasm-file into betteC #dlang-file format

`dlangfileFormat`


### Scenario: should transpile the wasm file to betterC file and execution it.

`ShouldTranspileTheWasmFileToBetterCFileAndExecutionIt`

*Given* the testsuite #dlang-file in betterC/D format.

`betterc_format`

*When* the #dlang-file has been compile in unittest mode.

`compile`

*Then* execute the unittest file and check that all unittests parses.

`run_test`


