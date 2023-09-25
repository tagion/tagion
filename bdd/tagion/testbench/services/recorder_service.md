Feature: Recorder chain service
This services should store the recorder for each epoch in chain as a file.
This is an extension of the Recorder backup chain.

Scenario: store of the recorder chain

Given a epoch recorder with epoch number has been received 

When the recorder has been store to a file

Then the file should be checked
