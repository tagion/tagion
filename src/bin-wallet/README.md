<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# Tagion 0.9.0 release
>Tagionwallet main application for working with tagion wallets

# Amount
```
--amount 
```
## Description
Show actual status/balance of your wallet
Example of using:
```
./tagionwallet --wallet tagionwallet.hibon --amount --pin 0000
```
<br>Show actual status of founds in wallet attached to file tagionwallet.hibon
```
Total: 100000.0
 Available: 100000.0
 Locked: 0.0
```
<br>Fail cases 
**unable open wallet file**
```
Wallet dont't exists
```
# Answers
```
--answers
```
## Description
Example of using: [see Creating wallet](#Creating-wallet)
Set list of answers for questions list ([see Questions](#Questions))
<br>Fail cases 
**answers count not equal **

# Contact file
```
-t --contract 
```
## Description


# Creating invoice
```
-c  --create-invoice 
```
## Description
Create invoice file
Example of using:
```
./tagionwallet --wallet tagionwallet.hibon --create-invoice InvoiceA:50 --pin 0000
```
<br>Create invoice file (default name: invoice_file.hibon) in context folder

# Creating wallet
```
--generate-wallet
```
## Description
Create wallet file
Example of using:
```
./tagionwallet --generate-wallet --pin 0000  --questions q1,q2,q3,q4 --answers a1,a2,a3,a4
```
Obligatorily needed keys:
--answers
--pin
--questions
<br>Fail cases 
**unable create wallet file**
<br> Exception in console or message about absent key or key value

# Device
```
--device
```
## Description

# Health
```
--help
```
## Description
Check connection and tagvion network status


# Help
```
-h --help
```

## Description
Show a short command list with basic description
Example of using:
```
./tagionwallet --help
```
<br>Out of help
```
Documentation: https://tagion.org/

Usage:
./tagionwallet [<option>...]

./tagionwallet <config.json> [--path <some-path>] # Uses the <config.json> instead of the default tagionwallet.json

Examples:
# To create an additional wallet in a different work-director and save the configuations
./tagionwallet --path wallet1 tagionwallet1.json -O

<option>:
           --version display the version
-O       --overwrite Overwrite the config file and exits
              --path Set the path for the wallet files : default 
            --wallet Wallet file : default tagionwallet.hibon
            --device Device file : default device.hibon
              --quiz Quiz file : default quiz.hibon
-i         --invoice Invoice file : default invoice_file.hibon
-c  --create-invoice Create invoice by format LABEL:PRICE. Example: Foreign_invoice:1000
-t        --contract Contractfile : default contract.hibon
-s            --send Send contract to the network
            --amount Display the wallet amount
-I             --pay Invoice to be payed : default 
-U          --update Update your wallet
-m            --item Invoice item select from the invoice file
-x             --pin Pincode
-p            --port Tagion network port : default 10800
-u             --url Tagion url : default localhost
-g          --visual Visual user interface
         --questions Questions for wallet creation
           --answers Answers for wallet creation
   --generate-wallet Create a new wallet
            --health Healthcheck the node
            --unlock Remove lock from all local bills
-h            --help This help information.
```
# Invoice
```
-i --invoice
```

## Description

# Invoice Item
```
-m --item
```

## Description

# GUI
```
-g --visual
```
## Description
Example of using:
```
./tagionwallet --visual
```
Show pseudographical GUI of wallet

# Pay invoice
```
--pay 
```
## Description
Perform payment with setted invoice file from default or setted wallet
Example of using:
```
./tagionwallet --pay /folder/invoice.hibon --pin 0000 --wallet tagionwallet.hibon
```
<br>Complete
```
Total: 100000.0
 Available: 100000.0
 Locked: 0.0
payment
```
<br>Fail case
Console exception

# Pin code
```
-x --pin
```
## Description
Set pincode in wallet or for actions with him
Example of using:
```
./tagionwallet --wallet tagionwallet.hibon --amount --pin 0000
```
<br>Complete operation how need pin code
<br>Fail case
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
## Description
Set a port for inter-node communication (default 10800).
Usable only with communicative commands, as like --health
Example of using:
```
./tagionwallet --port 10899
```

# Questions
```
--questions
```

## Description
Set list of questions, must be equal count with answers list
Example of using: [see Creating wallet](#Creating-wallet)
<br>Fail cases 
**Questions count not equal**

# Quiz
```
--quiz
```
## Description
Manipulation with q/a file (default quiz.hibon)

# Send
```
--send
```
## Description
Send command to network

# Update
```
-U --update 
```
## Description
Update the balance

# Unlock
```
--unlock
```
## Description