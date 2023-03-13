Feature Actor supervisor test

This feature should check the supervisor fail and restart

Scenario Supervisor with failing child

Given a actor #super 

Given a actor #child

When the actor #super start it should start the #child.

When the #child has started then the #child should fail with an exception

Then the #super actor should catch the #child which failed 

Then the #super actor should restart the child 
	It should be checked that child has been restarted success full

Then the #super should stop
	It should be checked that the #child actor has stopped successfully.
