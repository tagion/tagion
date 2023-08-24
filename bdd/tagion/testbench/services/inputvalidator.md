Feature Inputvalidator service

This feature should verify that the inputvalidator accepts valid and rejects invalid LEB128 input over a socket

## Scenario send a document to the socket

Given a inputvalidator

When we send a `Document` on a socket

Then we receive back the Document in our mailbox


## Scenario send random buffer

Given a inputvalidator

When we send a `random_buffer` on a socket

Then the inputvalidator rejects


## Scenario send malformed HiBON

Given a inputvalidator

When we send a `malformed_hibon` on a socket

Then the inputvalidator rejects


## Scenario send partial HiBON

Given a inputvalidator

When we send a `partial_hibon` on a socket

Then the inputvalidator rejects
