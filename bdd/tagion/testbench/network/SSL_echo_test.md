Feature: simple .c sslserver
This is a test for a very simple .c sslserver in order to understand our problem with connection refused.

Scenario: Send many requsts

Given: I have a simple _sslserver

Given: I have a simple _sslclient

When i send many requests repeatedly

Then the sslserver should not chrash.
