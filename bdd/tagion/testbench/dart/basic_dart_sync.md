Feature DARTSynchronization full sync
All test in this bdd should use dart fakenet. 

Scenario Full sync.
Given I have a dartfile1 with pseudo random data.
Given I have a empty dartfile2.
Given I synchronize dartfile1 with dartfile2.
Then the bullseyes should be the same.


 


