Feature Dart snap middle branch
All test in this bdd should use dart fakenet. This test covers after a archive has been removed, if when adding a new archive on top, that the branch snaps back. 

Scenario Add one archive and snap.
Given I have a dartfile with one archive.
Given I add one archive2 in the same sector.
Then the branch should snap back.


