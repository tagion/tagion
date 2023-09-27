feature: send a contract to the network.
scenario: send a single transaction from a wallet to another wallet.
given i have a dart database with already existing bills linked to wallet1.
given i make a payment request from wallet2.
when wallet1 pays contract to wallet2 and sends it to the network.
then wallet2 should receive the payment.
