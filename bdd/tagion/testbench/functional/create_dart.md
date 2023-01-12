Feature Add genesis wallets.
Scenario Generate dart.
Given I have wallets with pincodes
Given I initialize a Dart
When I add genesis invoice to N wallet
Then the dart should be generated
