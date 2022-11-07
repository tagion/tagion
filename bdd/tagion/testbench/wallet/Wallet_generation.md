Feature: Generate wallets.




Scenario: Seven wallets will be generated.

Given i have 7 pincodes and questions

When each wallet is created.

Then check if the wallet can be activated with the pincode.

