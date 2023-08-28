Feature Actor handler request

This feature should verify that you can request a handler for an actor that you don't own

Scenario send a message to an actor you don't own

Given a supervisor #super and one child actor #child

When #we request the handler for #child

When #we send a message to #child

When #we receive confirmation that shild has received the message.

Then stop the #super 
	check that #child has stopped also
