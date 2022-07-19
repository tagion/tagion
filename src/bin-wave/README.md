<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# Tagion tool v.x.x.x
> Brief tools description.
> The main binary file starts the 'main-node.' The 'main node' connects to the network, runs the hachgraph, and synchronizes the data. It is a full-fledged network node that can be used for operations with tagions, balance checking, etc.

#### [Tool link](https://github.com/tagion/tagion/tree/release/src/bin-wave)

# Table of contents
- [Tagion tool v.x.x.x](#tagion-tool-vxxx)
      - [Tool link](#tool-link)
- [Table of contents](#table-of-contents)
- [version](#version)
- [overwrite](#overwrite)
- [transaction-max](#transaction-max)
  - [Use cases](#use-cases)
    - [Case: input max amout of transactions](#case-input-max-amout-of-transactions)
      - [Success](#success)
      - [Failure](#failure)
    - [Case: negative input](#case-negative-input)
      - [Failure](#failure-1)
- [ip](#ip)
  - [Use cases](#use-cases-1)
    - [Case: input host gossip ip](#case-input-host-gossip-ip)
      - [Success](#success-1)
      - [Failure](#failure-2)
- [port](#port)
- [pid](#pid)
  - [Use Cases](#use-cases-2)
    - [Case: input file for pid](#case-input-file-for-pid)
      - [Success](#success-2)
      - [Failure](#failure-3)


# version
```
--version
```
Displays the version of tool

# overwrite
```
-O
--owerwrite
```
Overwrite the config file, to *tagionwave,json* by default

# transaction-max
```
-D
--transaction-max
```
Set max transactions for every node

## Use cases

### Case: input max amout of transactions

#### Success
```
./tagionwave -D 0
```
**Result**:<br>
```
----- Start tagion service task -----
Waiting for logger
REGISTER logger
Logger started
Register: tagionwave logger
...
```
#### Failure
```
./tagionwave -D 123456789
```
**Result**:<br>
```
Overflow in integral conversion
```
### Case: negative input

#### Failure
```
./tagionwave -D -10
```
**Result**:<br>
```
Unexpected '-' when converting from type string to type uint
```

# ip
```
--ip
```
Run network with current host gossip ip

## Use cases

### Case: input host gossip ip


#### Success
```
./tagionwave --ip 127.0.0.0
```

**Result**:<br>
```
----- Start tagion service task -----
Waiting for logger
REGISTER logger
Logger started
Register: tagionwave logger
...
```
#### Failure
```
./tagionwave --ip
```
**Result**:<br>
```
Missing value for argument --ip.
```

# port
```
--port
```
Set Host gossip port

# pid
```
--pid
```
Write Process IDentificator to input file

## Use Cases

### Case: input file for pid


#### Success
```
./tagionwave --pid file_for_pid
```
**Result**:<br>
```
----- Start tagion service task -----
PID = 141536 written to file_for_pid
Waiting for logger
REGISTER logger
Logger started
Register: tagionwave logger
...
```
#### Failure
```
./tagionwave --pid
```
**Result**:<br>
```
Missing value for argument --pid.
```