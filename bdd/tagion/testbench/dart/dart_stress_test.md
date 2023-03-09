Feature Dart pseudo random stress test
All test in this bdd should use dart fakenet. 

Scenario Add pseudo random data.
Given I have one dartfile.
Given I have a pseudo random sequence of data stored in a table with a seed.
When I increasingly add more data in each recorder and time it.
Then the data should be read and checked.

