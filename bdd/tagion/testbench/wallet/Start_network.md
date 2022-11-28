## Feature: Start network

`tagion.testbench.wallet.Start_network`

### Scenario: Start network in mode_one

`StartNetworkInModeOne`

*Given* i have wallets with pincodes

`pincodes`

*Given* i have a dart with genesis block

`genesisblock`

*When* network is started

`started`

*Then* the nodes should be in_graph

`ingraph`

*Then* one wallet should receive genesis amount

`amount`


