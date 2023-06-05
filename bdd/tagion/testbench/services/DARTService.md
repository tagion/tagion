## Feature: see if we can read and write trough the dartservice

`tagion.testbench.services.DARTService`

### Scenario: write and read from dart db

`WriteAndReadFromDartDb`

*Given* I have a dart db

`dartDb`

*Given* I have an dart actor with said db

`saidDb`

*When* I send a dartModify command with a recorder containing changes to add

`toAdd`

*When* I send a dartRead command to see if it has the changed

`theChanged`


```suggestion
*Then* the read recorder should be the same as the dartModify recorder
