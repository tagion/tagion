Feature insert random stress test
This test uses dartfakenet to randomly add and remove archives in the same recorder. 

Scenario add remove and read the result
Given i have a dartfile
Given i have an array of randomarchives
When i select n amount of elements in the randomarchives and add them to the dart and flip their bool. And count the number of instructions.
Then i read all the elements.

