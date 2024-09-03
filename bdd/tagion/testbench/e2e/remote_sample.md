Feature remote network test

Scenario we make a simple transaction on a remote network

Given i have 2 wallets a running network and shell

When i make a faucet request on wallet 1

When i send a transaction from wallet 1 to wallet 2

Then i expect the transaction to have been executed
