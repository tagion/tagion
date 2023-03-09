Feature Dart snap syncing
All test in this bdd should use dart fakenet. This test covers after a archive has been removed that was in a deep rim. What then happens when syncing such a branch?

Scenario Sync to another db.
Given I have a dartfile with one archive.
Given I have a empty dartfile2.
Given I sync the databases.
Then the bullseyes should be the same.
Then check if the data is not lost.


