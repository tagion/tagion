# Tagion wallet

The tagion wallet is a package [wallet](https://ddoc.tagion.org/tagion.wallet.html) which handles digital signature, signing of smart contract/payment and also information about the amount in the wallet.

## SecureWallet module
The secure wallet module takes care of holding the flowing informations.

1. Wallet generator (Enables the recovery of the wallet seed)
2. Devices recovery mechanism (Devices specific pin) 
3. Account details holds the information of the derivers,


[SecureWallet](https://ddoc.tagion.org/tagion.wallet.SecureWallet.SecureWallet.html)

### Create Wallet (method 1)

The first way to create a wallet is to select and number of question of which only the owner knows the question to. When the wallet is create owner answers the questions and a generator is created.

The owner can also supply a Device pin-code.

```mermaid
sequenceDiagram
    participant Answer_Questions
    participant Create_Wallet
    participant Wallet_Generator
    Answer_Questions->>Create_Wallet : Quiz(Question-Answers)
    Answer_Questions->>Create_Wallet : Device pin-code
    Create_Wallet->>Wallet_Generator : RecoverGenerator
```

This process produces the flowing data.
1. [Quiz](https://ddoc.tagion.org/tagion.wallet.WalletRecords.Quiz.html) which hold a list of questions
2. [RecoderGenerator](https://ddoc.tagion.org/tagion.wallet.WalletRecords.RecoverGenerator.html) which enables to recover the private-key for the questions in the *Quiz* and the correct answers.
3. [DevicePIN](https://ddoc.tagion.org/tagion.wallet.WalletRecords.DevicePIN.html) holds information which can generate the private-key from the correct device-pin.

#### Recover from the questions

The wallets private-key can be recovered with the correct answer
```mermaid
sequenceDiagram
    participant Recover_Wallet
    participant Answer_Questions
    participant Recovered_Wallet
	Recover_Wallet->>Answer_Questions : Quiz
	Recover_Wallet->>Answer_Questions : RecoverGenerator
	Answer_Questions->>Recovered_Wallet : Answers
```

Recover the wallet from the devices pin-code.
```mermaid
sequenceDiagram
    participant Recover_Wallet
    participant Device_PIN
    participant Recovered_Wallet
	Recover_Wallet->>Device_PIN: DevicePIN
	Device_PIN->>Recovered_Wallet : Correct pin 
```

### Create Wallet (method 2 BIP39)


### Create Wallet (method 1+2)


## Payment

The wallet is used both to send and receiver money. The exchange to information between the wallet is done via an Invoice

## Transfer to an invoice

The make a payment from on
