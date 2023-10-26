Feature send multiple contracts through the network

Scenario send N contracts from `wallet1` to `wallet2`
Given i have a network
When i send N many valid contracts from `wallet1` to `wallet2`
When all the contracts have been executed
Then wallet1 and wallet2 balances should be updated
