Feature: simple D client
This is a test with the C server and a simple D client.

Scenario: D Client with C server

Given: I have a simple _sslserver.
Given: I have a simple D _sslclient.
When: I send many requests repeadtly.
Then: the sslserver should not chrash.

Scenario: D Client multithreading with C server
Given: I have a a simple C sslserver.
Given: I have a D sslclient.
When: I send requests concurrently.
Then: the sslserver or client should not crash.