Feature: Multithreading
This is a test for multithread servers.

Scenario: C Client with C multithread_server

Given: I have a sslserver in C.
Given: I have a simple c _sslclient.
When: I send many requests with multithread.
Then: the sslserver should not chrash.

Scenario: D Client with C multithread_server

Given: I have a sslserver in C.
Given: I have a simple d _sslclient.
When: I send many requests with multithread.
Then: the sslserver should not chrash.
