## Feature: DARTSynchronization full sync
All test in this bdd should use dart fakenet.

`tagion.testbench.dart.basic_dart_sync`

### Scenario: Full sync.

`FullSync`

*Given* I have a dartfile1 with pseudo random data.

`randomData`

*Given* I have a empty dartfile2.

`emptyDartfile2`

*Given* I synchronize dartfile1 with dartfile2.

`withDartfile2`

*Then* the bullseyes should be the same.

`theSame`
 


