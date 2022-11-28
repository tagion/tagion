## Feature: Generate wallets.

`tagion.testbench.wallet.Wallet_generation`

### Scenario: Seven wallets will be generated.

`SevenWalletsWillBeGenerated`

*Given* i have 7 pincodes and questions

`questions`

*Given* i create wallets.

`createWallets`

*When* the wallets are created save the pin.

`pin`

*Then* check if the wallet can be activated with the pincode.

`pincode`


