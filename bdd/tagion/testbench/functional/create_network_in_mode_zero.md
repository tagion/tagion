Feature: Start network in mode zero

Scenario: Create network with n amount of nodes in mode_zero

Given i have _wallets

Given i have a dart with a genesis_block

When network is started

Then the nodes should be in_graph

Then the wallets should receive genesis amount

