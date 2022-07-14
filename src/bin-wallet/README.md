<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# Tagion 0.9.0 release
>Tagionwallet main application for working with tagion wallets
>
#### [Tool link](https://github.com/tagion/tagion)

# Table of contents
- [Tool link](#tool-link)
- [Table of contents](#table-of-contents)
- [Amount](#Amount)
- [Answers](#Answers)
- [Contract file](#Contract-file)
- [Creating invoice](#creating-invoice)
- [Creating wallet](#Creating-wallet)
- [Use cases](#Use-cases)
- [Device](#Device)
- [Health](#Health)
- [Invoice](#Invoice)
- [Invoice item](#Invoice-item)
- [GUI](#GUI)
- [path](#path)
- [Pay invoice](#Pay-invoice)
- [Pin code](#Pin-code)
- [Questions](#Questions)
- [Quiz](#Quiz)
- [Send](#Send)
- [Update](#Update)
- [Unlock](#Unlock)

# Amount
```
--amount 
```
Show actual status/balance of your wallet
Example of using:
```
./tagionwallet --wallet tagionwallet.hibon --amount --pin 0000
```
Show actual status of founds in wallet attached to file tagionwallet.hibon
## Use cases
_Brief description of both correct and error use cases_

### Perform check amount
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
Example of using: [see Creating wallet](#Creating-wallet)
Set list of answers for questions list ([see Questions](#Questions))
## Use cases
_Brief description of both correct and error use cases_

### Wallet creatin
#### Success
**Empty console**
#### Failure
**answers count not equal**

# Contract file
```
-t --contract 
```


# Creating invoice
```
-c  --create-invoice
```
Create invoice file
Example of using:
```
./tagionwallet --wallet tagionwallet.hibon --create-invoice InvoiceA:50 --pin 0000
```
## Use cases
_Brief description of both correct and error use cases_

### Run command
#### Success
**Empty line**
#### Failure
**Wrong pincode or unopened wallet file**

# Creating wallet
```
--generate-wallet
```
Create invoice file (default name: invoice_file.hibon) in context folder
Example of using:
```
./tagionwallet --generate-wallet --pin 0000  --questions q1,q2,q3,q4 --answers a1,a2,a3,a4
```
Obligatorily needed keys:
--answers
--pin
--questions
Optional keys
--path
--quiz
## Use cases
_Brief description of both correct and error use cases_

### Run command
#### Success
**Empty console**
#### Failure
**unable create wallet file**
**Exception in console or message about absent key or key value**

# Device
```
--device
```
Manipulation with device confige file (default device.hibon)
WIP

# Health
```
--health
```
Check connection and tagion network status
## Use cases
_Brief description of both correct and error use cases_

### Perform check
#### Success
```
HEALTHCHECK: localhost 10800
{"$@":"HiPRC","$msg":{"id":["u32",3668428660],"method":"healthcheck"}}
read rec_size=51
{"$@":"HiPRC","$msg":{"id":["u32",1],"result":{"inGraph":true,"rounds":["u64","0x8"]}}}

```
#### Failure
**Network error and console exception**

# Invoice
```
-i --invoice
```
# Invoice Item
```
-m --item
```

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
Setting path for creating wallet files [see Creating wallet](#Creating-wallet)
Not fully funtional - WIP

# Pay invoice
```
--pay
```
Perform payment with setted invoice file from default or setted wallet
Example of using:
```
./tagionwallet --pay /folder/invoice.hibon --pin 0000 --wallet tagionwallet.hibon
```
## Use cases
_Brief description of both correct and error use cases_

### make payment
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
**Console exceptions**

# Pin code
```
-x --pin
```
Set pincode in wallet or for actions with him
Example of using:
```
./tagionwallet --wallet tagionwallet.hibon --amount --pin 0000
```
## Use cases
_Brief description of both correct and error use cases_

### Entering pincode
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
Set list of questions, must be equal count with answers list
Example of using: [see Creating wallet](#Creating-wallet)
<br>Fail cases 
**Questions count not equal**

# Quiz
```
--quiz
```
Manipulation with q/a file (default quiz.hibon)
WIP

# Send
```
--send
```
Send command to network

# Update
```
-U --update 
```
Update the balance
Example of using:
```
./tagionwallet --update --amount --pin 01234
```
## Use cases
_Brief description of both correct and error use cases_

### Payment request
#### Success
```
Wallet updated true
```
#### Failure
**messages about error network**

# Unlock
```
--unlock
```
Unlocking reserved coins if transaction is fail