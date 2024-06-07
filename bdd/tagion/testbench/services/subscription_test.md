Feature Subscription service

This feature verifies the basic features of the subscription service

## Scenario receive subscribed topics on a socket

Given a subscription service

When we subscribe to a topic which is enabled we should receive a document

When we subscribe to a topic which is not enabled we should not receive a document

Then we stop the service
