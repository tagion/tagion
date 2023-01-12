Feature: Generate transaction
Scenario: Create transaction
Given a network.
Given the network have a wallet A with tagions.
Given the wallets have an invoice in another_wallet.
When wallet A pays the invoice.
When the contract is executed.
Then the balance should be checked against all nodes.
Then wallet B should receive the invoice amount.
Then wallet A should loose invoice amount + fee.
Then the bullseye of all the nodes DARTs should be the same.
But the transaction should not take longer than Tmax seconds.
But the transaction should finish in 8 epochs. 