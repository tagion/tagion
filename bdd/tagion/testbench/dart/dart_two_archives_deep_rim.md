Feature Dart two archives deep rim
All test in this bdd should use dart fakenet. 

Scenario Add one archive.
mark #one_archive
Given I have a dartfile.
Given I add one archive1 in a sector.
Then the archive should be read and checked.

Scenario Add another archive.
mark #two_archives
Given #one_archive
Given i add another archive2 in the same sector, 5 rims deep as archive1.
Then both archives should be read and checked.
Then check sector_A.
Then check the _bullseye.
 
Scenario Remove archive
Given #two_archives
Given i remove archive1.
Then check that archive2 has been moved from the branch in sector A.
Then check the _bullseye.

