## Feature: Dart pseudo random stress test
All test in this bdd should use dart fakenet.

`tagion.testbench.dart.dart_stress_test`

### Scenario: Add pseudo random data.

`AddPseudoRandomData`

*Given* I have one dartfile.

`dartfile`

*Given* I have a pseudo random sequence of data stored in a table with a seed.

`seed`

*When* I increasingly add more data in each recorder and time it.

`it`

*Then* the data should be read and checked.

`checked`
