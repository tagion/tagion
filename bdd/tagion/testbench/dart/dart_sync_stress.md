Feature Sync insert random stress test

Scenario add remove and read the result
Given i two dartfiles.
Given i have an array of randomarchives
When i select n amount of elements in the randomarchives and add them to the dart and flip their bool. And count the number of instructions.
When i sync the new database with another and check the bullseyes of the two databases.
Then i read all the elements of both darts.


