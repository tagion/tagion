## Feature: Test of the NNG wrapper.
This Feature test of NNG sockets and services.
NNG source: https://github.com/nanomsg/nng

`tagion.testbench.nng.nng_testsuite`

### Scenario: push-pull socket should send and receive byte buffer.

`PushpullSocketShouldSendAndReceiveByteBuffer`

*Given* a receiver and a sender worker has been spawn.

`spawn_worker`

*When* wait until the worker has completed the conversation.

`conversation`

*Then* check that communication has passed with out errors.

`errors`


