# Tagion wallet (Geldbeutel)

```
Documentation: https://tagion.org/

Usage:
geldbeutel [<option>...] <config.json> <files>

<option>:
     --version display the version
-O --overwrite Overwrite the config file and exits
        --path Set the path for the wallet files : default 
      --wallet Wallet file : default wallet.hibon
      --device Device file : default device.hibon
        --quiz Quiz file : default quiz.hibon
-C    --create Create a new account
-c --changepin Change pin-code
-x       --pin Pincode
-h      --help This help information.
```

## Write wallet configuration file `wallet.json`
This will write a configuration file `wallet.json` and the wallet will be placed in `$HOME/wallet`.  
```
geldbeutel -O --path $HOME/wallet/
```

>Tagionwallet main application for working with tagion wallets

# Amount
```
--amount 
```
Show actual status/balance of your wallet<br>
Example of using:
```
./tagionwallet --amount --pin 0000
```
Show actual status of founds in wallet attached to file tagionwallet.hibon<br>
Available status - money enable for new transaction<br>
Locked status - reserved money for transaction in processing<br>
without --update key possible works offline.<br>
## Parameters
[--update](#update) **optional** update data with amount<br>
[--wallet](#wallet) **optional** set custom wallet

## Use cases

### Case: Perform check amount
```
./tagionwallet --amount --update --pin 0000
```
#### Success
```
Total: 100000.0
 Available: 100000.0
 Locked: 0.0
```
#### Failure
**unable open wallet file**
```
Wallet dont't exists
```
# Answers
```
--answers
```
Example of using: [see Creating wallet](#Creating-wallet)<br>
Set list of answers for questions list ([see Questions](#Questions))
## Parameters
[--generate-wallet](#creating-wallet) **requred** main command line key<br>
[--questions](#questions) **requred** always used in pair<br>
[--pin](#pin-code) **optional** pin code always need set, if key absent set key from GUI ([see](#gui))

## Use cases

### Case: Wallet creating
[see](#use-cases-3)
#### Success
**Empty console**
#### Failure
**answers count not equal**

# Contract file
```
-t --contract 
```
Set path contact file<br>
Example of using:
```
./tagionwallet --contract contract_file.hibon
```

# Creating invoice
```
-c  --create-invoice
```
Create invoice file<br>
Example of using:
```
./tagionwallet --wallet tagionwallet.hibon --create-invoice InvoiceA:50 --pin 0000
```
## Parameters
[--invoice](#invoice) **optional** set name for invoice file<br>
[--wallet](#wallet) **optional** set wallet custom file<br>
[--pin](#pin-code) **optional** if absent - need set pin in GUI<br>
[--path](#path) **optional** set path to wallet files

## Use cases

### Case: Run command
#### Success
**Empty console line**<br>
invoice file (default name "invoice_file.hibon") created in context folder
#### Failure
**Wrong pincode or unopened wallet file**

# Creating wallet
```
--generate-wallet
```
Create invoice file (default name: tagionwallet.hibon) in context folder<br>
Example of using:
```
./tagionwallet --generate-wallet --pin 0000  --questions q1,q2,q3,q4 --answers a1,a2,a3,a4
```
## Parameters
[--answers](#Answers) **required** set answers list<br>
[--pin](#pin-code) **optional** if absent - need set pin in GUI<br>
[--questions](#questions) **required** set questions list<br>
[--path](#path) **optional** Refactoring<br>
[--quiz](#quiz) **optional** Refactoring

## Use cases

### Case: Run command
#### Success
**Empty console**
Wallet files success created
#### Failure
**unable create wallet file**<br>
**Exception in console(Refactoring) or message about absent key or key value**

# Device
```
--device
```
Manipulation with device confige file (default device.hibon)<br>
WIP<br>
Example of using:
```
./tagionwallet --device device.hibon
```
**Refactoring**

# Health
```
--health
```
Check connection and tagion network status<br>
Example of using:
```
./tagionwallet --health
```
## Parameters
[--port](#port) **optional** set non default port

## Use cases

### Case: Perform check
```
./tagionwallet --health --port 10910
```
#### Success
**Refactoring(Actual output)**
```
HEALTHCHECK: localhost 10800
{"$@":"HiPRC","$msg":{"id":["u32",3668428660],"method":"healthcheck"}}
read rec_size=51
{"$@":"HiPRC","$msg":{"id":["u32",1],"result":{"inGraph":true,"rounds":["u64","0x8"]}}}

```
**Refactoring(WIP output)**
```
In hashgraph: true
Current round: 19
```
#### Failure
```
Health check failed: Unable to connect socket: Connection refused
```

# Invoice
```
-i --invoice
```
Set path to new invoice file, optional key for [Create invoice](#creating-invoice)
**WIP**

# Invoice Item
```
-m --item
```
**WIP**

# GUI
```
-g --visual
```
Example of using:
```
./tagionwallet --visual
```
Show pseudographical GUI of wallet

# path
```
--path
```
Setting path for creating wallet files [see Creating wallet](#Creating-wallet)<br>
Not fully funtional - WIP

# Pay invoice
```
--pay
```
Perform payment with setted invoice file from default or setted wallet<br>
Example of using:
```
./tagionwallet --pay /folder/invoice.hibon --pin 0000 --wallet tagionwallet.hibon
```

## Parameters
[--port](#port) **optional** set non default port<br>
[--pin](#pin-code) **optional** if absent - need set pin in GUI<br>
[--wallet](#wallet) **optional** set wallet custom file

## Use cases

### Case: make payment
```
./tagionwallet --pay /folder/invoice.hibon --pin 0000
```
#### Success
```
Total: 100000.0
 Available: 100000.0
 Locked: 0.0
payment
```
#### Failure
```
payment
payment failed
```
**Console exceptions(Refactoring)**
```
HiBON Document format failed
```
```
Wrong pincode
```

# Pin code
```
-x --pin
```
Set pincode in wallet or for actions with him<br>
Example of using:
```
./tagionwallet  --amount --pin 0000
```
## Use cases

### Case: Entering pincode
[see](#amount)
#### Success
Complete operation how need pin code
#### Failure
```
Wrong pincode
```
```
Missing value for argument --pin.
```

# Port
```
--port
```
Set a port for inter-node communication (default 10800).<br>
Usable only with communicative commands, as like --health.<br>
Also possible use custom port for dev-mode (diapasone 10910 .. 10920) or docker environment 10800 .. 10820<br>
Example of using:
```
./tagionwallet --port 10899
```
## Use cases
### Case: payment with port
```
./tagionwallet  --pay invoice_file.hibon --pin 01234 --send --port 10911
```
#### Success
**operation complete**
#### Failed
```
payment
payment failed
```
<br>Not work network:
```
Health check failed: Unable to connect socket: Connection refused
```

# Questions
```
--questions
```
Set list of questions, must be equal count with answers list<br>
Example of using: [see Creating wallet](#Creating-wallet)
<br>Fail cases 
**Questions count not equal**

## Use cases
[see](#use-cases-3)

## Parameters
[--answers](#Answers) **required** set answers list<br>
[--generate-wallet](#creating-wallet) **requred** main command line key<br>
[--pin](#pin-code) **optional** if absent - need set pin in GUI

# Quiz
```
--quiz
```
Manipulation with q/a file (default quiz.hibon)<br>
WIP

# Send
```
--send
```
Send command to network<br>
Example of using:
```
./tagionwallet --pay invoice.hibon --pin 01234 --send
```
## Parameters
[--pin](#pin-code) **optional** if absent - need set pin in GUI<br>
[--pay](#pay) **optional** for sending invoice<br>
[--port](#port) **optional** set non default port

## Use cases
[see](#port)

# Update
```
-U --update
```
Update the balance<br>
Example of using:
```
./tagionwallet --update --amount --pin 01234
```
## Parameters
[--amount](#amount) **optional** can be used with --update for actual amount<br>
[--pin](#pin-code) **optional** if absent - need set pin in GUI<br>
[--port](#port) **optional** set non default port<br>
[--wallet](#wallet) **optional** set custom wallet

## Use cases

### Case: Payment request
[see](#amount)
#### Success
```
Wallet updated true
```
#### Failure
**messages about error network**
### Case: Update amount
[see](#use-cases)

# Unlock
```
--unlock
```
Unlocking reserved coins if transaction is fail

# Wallet
```
--wallet
```
Set custom wallet file<br>
Example of using:
```
./tagionwallet --update --amount --pin 01234 --wallet file_wallet.hibon
```
## Use cases

### Case: Check balance
[see](#amount)
#### Success
```
Total: 100000.0
 Available: 0.0
 Locked: 100000.0
```
#### Failure
**Wrong pincode**
**Absent file(Refactoring)**
<br>incorrect file format
```
HiBON Document format failed
```
