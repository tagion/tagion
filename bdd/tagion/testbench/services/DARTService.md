Feature: see if we can read and write trough the dartservice
Scenario: write and read from dart db
Given I have a dart db
Given I have an dart actor with said db
When I send a dartModify command with a recorder containing changes to add
When I send a dartRead command to see if it has the changed
Then the read recorder should be the same as the dartModify recorder

