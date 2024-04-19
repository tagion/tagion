Feature: wallet scenarios

Scenario: CreateWallet
Given empty folder for creating a wallet
When set wallet folder and config file
When set password and pin
Then wallet folder should contanin non-empty wallet hibon files
