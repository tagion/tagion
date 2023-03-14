## Feature: Dart snap syncing
All test in this bdd should use dart fakenet. This test covers after a archive has been removed that was in a deep rim. What then happens when syncing such a branch?

`tagion.testbench.dart.dart_sync_snap_back`

### Scenario: Sync to another db.

`SyncToAnotherDb`

*Given* I have a dartfile with one archive.

`archive`

*Given* I have a empty dartfile2.

`dartfile2`

*Given* I sync the databases.

`databases`

*Then* the bullseyes should be the same.

`same`

*Then* check if the data is not lost.

`lost`
