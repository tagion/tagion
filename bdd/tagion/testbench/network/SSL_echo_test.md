## Feature: SSL simple echo test
This is simple SSL socket test between a client and a server

`tagion.testbench.network.SSL_echo_test`

### Scenario: Should start a SSL test server
This test server is a simple C program which should respond to ssl client connecting to it.

`ShouldStartASSLTestServer`

*Given* that a SSL-test server should be started

`started`

*When* a SSL-client connect and send a message
The client should send and receive a known message to the server
and check the response.

`message`

*Then* a client should send a message to shutdown server.

`server`


