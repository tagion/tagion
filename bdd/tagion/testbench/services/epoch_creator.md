Feature: EpochCreator service
This service is responsible for resolving the Hashgraph and producing a consensus ordered list of events, an Epoch.

Scenario: Send payload and create epoch
Given: I have 5 nodes and start them in mode0
When i sent a payload to node0
Then all the nodes should create an epoch containing the payload
