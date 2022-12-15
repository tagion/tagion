Feature: Test server module with multiple client connection 

This test setup an multi-client server


Scenario: A server module with capable to service multi client should be test

Given  the server has been stated

Given multiple clients has been stated and connected to the server

When the clients has send and receive verified data

Then the clients should disconnects to the server.

Then the server should verify that all clients has been disconnect 

Then the server should stop





