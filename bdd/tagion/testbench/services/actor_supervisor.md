## Feature Actor supervisor test

This feature should check that when a child catches an exception is sends it up as a failure.
The supervisour has the abillity to decide whether or not to restart i depending on the exception.

### Scenario Supervisor with failing child

*Given* a actor #super 

*When* the #super and the #child has started

*Then* the #super should send a message to the #child which results in a fail

*Then* the #super actor should catch the #child which failed 

*Then* the #super actor should stop #child and restart it
	It should be checked that child has been restarted successfully

*Then* the #super should send a message to the #child which results in a different fail

*Then* the #super actor should let the #child keep running
	It should be checked that child keeps running successfully

*Then* the #super should stop
	It should be checked that the #child actor has stopped successfully.
