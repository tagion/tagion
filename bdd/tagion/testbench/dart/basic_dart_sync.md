Feature DARTSynchronization
All test in this bdd should use dart fakenet. 

Scenario Full sync.
Given I have a dartfile1 with pseudo random data.
Given I have a empty dartfile2.
Given I synchronize dartfile1 with dartfile2.
Then the bullseyes should be the same.

Scenario Partial sync.
Given I have a dartfile1 with pseudo random data.
Given I have added some of the pseudo random data to dartfile2.
Given I synchronize dartfile1 with dartfile2.
Then the bullseyes should be the same.
 


