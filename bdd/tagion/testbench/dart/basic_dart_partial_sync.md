## Feature: DARTSynchronization partial sync.
All test in this bdd should use dart fakenet.

`tagion.testbench.dart.basic_dart_partial_sync`

### Scenario: Partial sync.

`PartialSync`

*Given* I have a dartfile1 with pseudo random data.

`randomData`

*Given* I have added some of the pseudo random data to dartfile2.

`toDartfile2`

*Given* I synchronize dartfile1 with dartfile2.

`withDartfile2`

*Then* the bullseyes should be the same.

`theSame`

