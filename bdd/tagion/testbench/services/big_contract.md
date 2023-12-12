feature: send a contract with many outputs to the network.
scenario: send a single transaction from a wallet to another wallet with many outputs.
given i have a dart database with already existing bills liked to _wallet1
given i make multiple payment requests in _wallet2
when i pay all of the requests from wallet2 and send it to the network
then the contract should go through
