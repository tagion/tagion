Feature Dart pseudo random test
All test in this bdd should use dart fakenet. 

Scenario Add pseudo random data.
Given I have two dartfiles.
Given I have a pseudo random sequence of data stored in a table with a seed.
When I randomly add all the data stored in the table to the two darts. 
Then the bullseyes of the two darts should be the same.


