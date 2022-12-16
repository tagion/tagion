Feature: Test server module with multiple client connection 

This test setup an multiple-clients to server module and test the communication between the clients and server.


Scenario: A server module with capable to service multi client should be test

Given the server should been stated

Given multiple clients should been stated and connected to the server

When the clients should send and receive verified data

Then the clients should disconnects to the server.

Then the server should verify that all clients has been disconnect 

Then the server should stop





