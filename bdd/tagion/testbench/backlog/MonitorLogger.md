## Feature: Connection remote to the logger service.

This feature takes care of the communication between the logger client and the logger service. 



### Scenario: Connecting the logger client to logger service

*Given* the logger client is started

*Given* the client is connected to the logger service

*When* the client is connected success fully.

*Then* send credential request to the logger.

*Then* check that the credential has been verified. 



### Scenario: Rejection of the logger client.

*Given* the logger client is started
*Given* the client is connected to the logger service

*When* the client is connected success fully 

*Then* send bad credential request to the logger.

*Then* check that the credential has been rejected. 



