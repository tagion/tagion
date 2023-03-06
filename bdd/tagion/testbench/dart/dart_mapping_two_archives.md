Feature Dart mapping of two archives
All test in this bdd should use dart fakenet. 

Scenario Add one archive.
mark #one_archive
Given I have a dartfile.
Given I add one archive1 in sector A.
Then the archive should be read and checked.

Scenario Add another archive.
mark #two_archives
Given #one_archive
Given i add another archive2 in sector A.
Then both archives should be read and checked.
Then check the branch of sector A.
Then check the bullseye.
 
Scenario Remove archive
Given #two_archives
Given i remove archive1.
Then check that archive2 has been moved from the branch in sector A.
Then check the bullseye.


