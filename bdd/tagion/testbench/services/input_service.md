Feature Inputvalidator service

This feature should verify that the inputvalidator accepts valid and rejects invalid LEB128 input over a socket

Scenario send a document to the socket

Given a inputvalidator

When we send a `Document` on a socket

When we receive back the Document in our mailbox

Then stop the inputvalidator
