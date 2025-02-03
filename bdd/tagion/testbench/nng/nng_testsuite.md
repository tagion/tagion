## Feature: Test of the NNG wrapper.
This Feature test of NNG sockets and services.
NNG source: https://github.com/nanomsg/nng

`tagion.testbench.nng.nng_testsuite`

### Scenario: NNG embedded multithread testsuite.

`MultithreadedNNGTestSuiteWrapper`

*Given* Multithreaded Test Suite instantince.

`create`

*When* wait until the Multithreaded Test Suite work over tests.

`runtests`

*Then* check that teste has passed without errors.

`errors`


