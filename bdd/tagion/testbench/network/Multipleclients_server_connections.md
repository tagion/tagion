Feature: Test server module with multiple client connection 

This test setup an multiple-clients to server module and test the communication between the clients and server.


Scenario: A server module which should be capable of servicing multiple clients

Given the server should been stated

Given multiple clients should been stated and connected to the server in sequence

Given multiple clients should been started at the same time (in parallel).

When the clients should send and receive verified data

Then the clients should disconnects to the server.

Then the server should verify that all clients has been disconnect 

Then the server should stop





