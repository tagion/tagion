# Logger Subscription Services

This services takes care of the remote logging and event subscription.

Events are generated through a special log function which takes a topic and a hibon document. 
The events must be enabled at startup in the [subscription service options](https://ddoc.tagion.org/tagion.services.subscription.SubscriptionServiceOptions.html).
All the enabled events are then published through a nng pub socket at the configured address.
The events consist of a the raw topic name seperated by a null byte `\0` and then a [payload document](https://ddoc.tagion.org/tagion.services.subscription.SubscriptionPayload.html)
