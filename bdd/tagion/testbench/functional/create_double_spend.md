Feature: Verify that double spend cant occur
Scenario: Double spend same wallet
Given a network.
Given the network have a wallet A with tagions.
Given wallet A has two invoices with same input bill to wallet_b.
When wallet A pays both the invoices.
When the contract is executed.
Then the balance should be checked against all nodes.
Then wallet B should only receive the invoice amount.
Then wallet A should loose invoice amount + fee.
Then the bullseye of all the nodes DARTs should be the same.
But the transaction should not take longer than Tmax seconds.
But the transaction should finish in 8 epochs. 