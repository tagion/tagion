## Feature actor taskfailure

This feature should verify that when an actor receives a TaskFailure.
While there is no handling of that type of taskfailure resend it up to the owner.

### Scenario Send a TaskFailure to an actor

*Given* an #actor

*When* the #actor has started

*Then* send a `TaskFailure` to the actor

*Then* the actor should echo it back to the main thread

*Then* stop the #actor
