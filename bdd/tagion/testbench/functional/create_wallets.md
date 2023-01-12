Feature: Generate wallets.

Scenario: Generate n wallets.

Given i have n pincodes and questions

Given i create wallets.

When the wallets are created save the pin.

Then check if the wallet can be activated with the pincode.

