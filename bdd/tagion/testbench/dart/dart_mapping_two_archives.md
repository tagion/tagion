## Feature: Dart mapping of two archives
All test in this bdd should use dart fakenet.

`tagion.testbench.dart.dart_mapping_two_archives`

### Scenario: Add one archive.
mark #one_archive

`AddOneArchive`

*Given* I have a dartfile.

`dartfile`

*Given* I add one archive1 in sector A.

`a`

*Then* the archive should be read and checked.

`checked`


### Scenario: Add another archive.
mark #two_archives

`AddAnotherArchive`

*Given* #one_archive

`onearchive`

*Given* i add another archive2 in sector A.

`inSectorA`

*Then* both archives should be read and checked.

`readAndChecked`

*Then* check the branch of sector A.

`ofSectorA`

*Then* check the bullseye.

`checkTheBullseye`


### Scenario: Remove archive

`RemoveArchive`

*Given* #two_archives

`twoarchives`

*Given* i remove archive1.

`archive1`

*Then* check that archive2 has been moved from the branch in sector A.

`a`

*Then* check the bullseye.

`bullseye`


