Feature Nodeinterface service

Scenario pubkey A sends a message to pubkey B
Given i have 2 listening node interfaces
When i send a message from A to B
Then B should receive the message
