Feature Actor messaging

This feature should verify the message send between actors

Scenario Message between supervisor and child

Given a supervisor #super and two child actors #child1 and #child2

When the #super has started the #child1 and #child2

Then send a message to #child1 

Then send this message back from #child1 to #super

Then send a message to #child2

Then send thus message back from #child2 to #super

Then stop the #super 
	check that #child1 and #child2 has stopped also


Scenario send message between two children

Given a supervisor #super and two child actors #child1 and #child2

When the #super has started the #child1 and #child2

When send a message from #super to #child1 and from #child1 to #child2 and back to the #super
	Check that message has been received correctly

Then stop the #super 
