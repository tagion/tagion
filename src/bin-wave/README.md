<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# Tagion tool v.x.x.x
> The binary files starts the 'master-node.' The 'master node' connects to the network, runs the hashgraph, and synchronizes the data. It is a full-fledged network node that can be used for operations with tagions, balance checking, etc. <br>

There are three modes to run the network: <br>
[mode0](#mode0) <br>
[mode1](#mode1) <br>
[mode2](#mode2) <br>

Tools that will be used here

[tagionwallet](https://github.com/tagion/tagion/tree/develop/src/bin-wallet)

[dartutil](https://github.com/tagion/tagion/tree/develop/src/bin-dartutil)

[tagionboot](https://github.com/tagion/tagion/tree/develop/src/bin-boot)

# mode0
>mode0 is interprocess communication mode, each node in the network represented as a thread
Main purpose of Mode0 is functional testing of the network and node, to run network in mode0, you need to follow the instructions below:<br>
```
mkdir data
cd data
mkdir node0
cd ..
dartutil --initialize --dartfilename dart.drt
mv dart.drt data/node0/
tagionwave --dart-init=false --nodes 4 --dart-synchronize=true --net-mode=internal
```
[dart-synchronize](#dart-synchronize) **required** (Regular node should be synchronize, and not synchronize for master node)<br>
[dart-init](#dart-init) **required** (Init empty DART)<br>
[nodes](#nodes) **required** (Number of active nodes)<br>
[net-mode](#net-mode) **required** (Set mode for network)
# mode1
> mode1 is local mode, you can make transactions on the local machine, separate terminal - separate node. Essentially, mode0 is part of mode1. To run network in mode1, you need to follow the instructions below:<br>
> Add binaries to PATH
```
export PATH="$PATH:$HOME/dir_name/tagion/build/x86_64-linux/bin"
```
> Then you need to create wallets and init DART<br>
> Wallet 1
```
mkdir -p tagion_network
cd tagion_network
mkdir -p data/node0
mkdir shared
cd data
dartutil --initialize --dartfilename dart.drt
cd ..
mkdir -p wallet_1
cd wallet_1
tagionwallet --generate-wallet --questions q1,q2,q3,q4 --answers a1,a2,a3,a4 -x 0001
tagionwallet --create-invoice GENESIS:100000 -x 0001
tagionboot invoice_file.hibon -o genesis.hibon
cd ..
dartutil --dartfilename ./data/dart.drt --modify --inputfile ./wallet_1/genesis.hibon
```
>Wallet 2
```
mkdir -p wallet_2
cd wallet_2
tagionwallet --generate-wallet --questions q1,q2,q3,q4 --answers a1,a2,a3,a4 -x 0002
tagionwallet --create-invoice GENESIS:100000 -x 0002
tagionboot invoice_file.hibon -o genesis.hibon
cd ..
dartutil --dartfilename ./data/dart.drt --modify --inputfile ./wallet_2/genesis.hibon
```
>Same you can create another wallets
```
cp ./data/dart.drt ./data/node0/dart.drt
```
>Next we can launch network with 4 nodes
```
rm -f ./shared/*
gnome-terminal --tab -- tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log --nodes 4

gnome-terminal --tab -- tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart2.drt --port=4002 --transaction-port=10802 --logger-filename=./shared/node-2.log --nodes 4

gnome-terminal --tab -- tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart3.drt --port=4003 --transaction-port=10803 --logger-filename=./shared/node-3.log --nodes 4

gnome-terminal --tab -- tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=false --dart-synchronize=false --dart-path=./data/dart.drt --port=4020 --transaction-port=10820 --logger-filename=./shared/node-master.log --nodes 4
```

[boot](#boot) **required** (Set boot.hibon file)

[port](#port) **required** (Set port gor host gossip ip)

[dart-init](#dart-init) **required** (Init empty DART)

[net-mode](#net-mode) **required** (Set mode for network)

[dart-synchronize](#dart-synchronize) **required** (Regular node should be synchronize, and not synchronize for master node)

[dart-path](#dart-path) **required** (Set path for DART file)

[transaction-port](#transaction-port) **required** (Set port for transactions)

[logger-filename](#logger-filename) **optional** (Set file for logs)

[nodes](#nodes)  **required** (Number of active nodes)
# mode2
**TBD**

#### [Tool link](https://github.com/tagion/tagion/tree/release/src/bin-wave)
# Table of contents
- [Tagion tool v.x.x.x](#tagion-tool-vxxx)
- [mode0](#mode0)
- [mode1](#mode1)
- [mode2](#mode2)
- [Table of contents](#table-of-contents)
- [version](#version)
- [overwrite](#overwrite)
  - [Use cases](#use-cases)
    - [Case: overwrite config file](#case-overwrite-config-file)
      - [Success](#success)
    - [Case: overwrite config file without param](#case-overwrite-config-file-without-param)
      - [Success](#success-1)
- [transaction-max](#transaction-max)
  - [Use cases](#use-cases-1)
    - [Case: input max amount of transactions](#case-input-max-amount-of-transactions)
      - [Success](#success-2)
    - [Case: invalid input](#case-invalid-input)
      - [Failure](#failure)
    - [Case: invalid input](#case-invalid-input-1)
      - [Failure](#failure-1)
- [ip](#ip)
  - [Use cases](#use-cases-2)
    - [Case: input host gossip ip](#case-input-host-gossip-ip)
      - [Success](#success-3)
    - [Case: empty host gossip ip](#case-empty-host-gossip-ip)
      - [Failure](#failure-2)
- [port](#port)
  - [Use cases](#use-cases-3)
    - [Case: set gossip port](#case-set-gossip-port)
      - [Success](#success-4)
    - [Case: invalid value for gossip port](#case-invalid-value-for-gossip-port)
      - [Failure](#failure-3)
- [pid](#pid)
  - [Use Cases](#use-cases-4)
    - [Case: input file for pid](#case-input-file-for-pid)
      - [Success](#success-5)
    - [Case: empty file for pid](#case-empty-file-for-pid)
      - [Failure](#failure-4)
- [nodes](#nodes)
  - [Use Cases](#use-cases-5)
    - [Case: set nodes amount](#case-set-nodes-amount)
      - [Success](#success-6)
    - [Case: invalid nodes number](#case-invalid-nodes-number)
      - [Failure](#failure-5)
- [seed](#seed)
- [timeout](#timeout)
  - [Use Cases](#use-cases-6)
    - [Case: set timeout](#case-set-timeout)
      - [Success](#success-7)
    - [Case: invalid value for timeout](#case-invalid-value-for-timeout)
      - [Failure](#failure-6)
- [delay](#delay)
- [trace-gossip](#trace-gossip)
- [loops](#loops)
- [url](#url)
- [sockets](#sockets)
  - [Use Cases](#use-cases-7)
    - [Case: set max number of open monitors](#case-set-max-number-of-open-monitors)
      - [Success](#success-8)
    - [Case: invalid value](#case-invalid-value)
      - [Failure](#failure-7)
- [tmp](#tmp)
  - [Use Cases](#use-cases-8)
    - [Case: input directory for tmp](#case-input-directory-for-tmp)
      - [Success](#success-9)
    - [Case: empty directory name for tmp](#case-empty-directory-name-for-tmp)
      - [Failure](#failure-8)
- [monitor](#monitor)
  - [Use cases](#use-cases-9)
    - [Case: set first monitor port](#case-set-first-monitor-port)
      - [Success](#success-10)
    - [Case: invalid value](#case-invalid-value-1)
      - [Failure](#failure-9)
- [stdout](#stdout)
- [transaction-ip](#transaction-ip)
  - [Use cases](#use-cases-10)
    - [Case: input transaction ip](#case-input-transaction-ip)
      - [Success](#success-11)
    - [Case: empty transaction ip](#case-empty-transaction-ip)
      - [Failure](#failure-10)
- [transaction-port](#transaction-port)
  - [Use cases](#use-cases-11)
    - [Case: set port](#case-set-port)
      - [Success](#success-12)
    - [Case: invalid value for port](#case-invalid-value-for-port)
      - [Failure](#failure-11)
- [transaction-queue](#transaction-queue)
  - [Use Cases](#use-cases-12)
    - [Case: set max number of listeners](#case-set-max-number-of-listeners)
      - [Success](#success-13)
    - [Case: invalid value for max number of listeners](#case-invalid-value-for-max-number-of-listeners)
      - [Failure](#failure-12)
- [transaction-maxcon](#transaction-maxcon)
  - [Use Cases](#use-cases-13)
    - [Case: set max connections number](#case-set-max-connections-number)
      - [Success](#success-14)
    - [Case: empty value for max connections number](#case-empty-value-for-max-connections-number)
      - [Failure](#failure-13)
- [transaction-maxqueue](#transaction-maxqueue)
  - [Use Cases](#use-cases-14)
    - [Case: set max connections number](#case-set-max-connections-number-1)
      - [Success](#success-15)
    - [Case: empty value for max connections number](#case-empty-value-for-max-connections-number-1)
      - [Failure](#failure-14)
- [epochs](#epochs)
  - [Use Cases](#use-cases-15)
    - [Case: set epochs number](#case-set-epochs-number)
      - [Success](#success-16)
    - [Case: invalid value for epochs](#case-invalid-value-for-epochs)
      - [Failure](#failure-15)
- [transcript-from](#transcript-from)
- [transcript-to](#transcript-to)
- [transcript-log](#transcript-log)
  - [Use Cases](#use-cases-16)
    - [Case: set filename for transcript log](#case-set-filename-for-transcript-log)
      - [Success](#success-17)
    - [Case: empty input](#case-empty-input)
      - [Failure](#failure-16)
- [transcript-debug](#transcript-debug)
- [dart-filename](#dart-filename)
  - [Use Cases](#use-cases-17)
    - [Case: set new DART file name](#case-set-new-dart-file-name)
      - [Failure](#failure-17)
- [dart-synchronize](#dart-synchronize)
  - [Use Cases](#use-cases-18)
    - [Case: need synchronization](#case-need-synchronization)
      - [Success](#success-18)
    - [Case: Invalid input for dart-synchronize](#case-invalid-input-for-dart-synchronize)
    - [Failure](#failure-18)
- [dart-angle-from-port](#dart-angle-from-port)
- [dart-master-angle-from-port](#dart-master-angle-from-port)
- [dart-init](#dart-init)
  - [Use cases](#use-cases-19)
    - [Case: init DART](#case-init-dart)
      - [Success](#success-19)
    - [Case: invalid value for dart init](#case-invalid-value-for-dart-init)
      - [Failure](#failure-19)
- [dart-generate](#dart-generate)
- [dart-from](#dart-from)
- [dart-to](#dart-to)
- [dart-request](#dart-request)
- [dart-path](#dart-path)
  - [Use Cases](#use-cases-20)
    - [Case: set DART file path](#case-set-dart-file-path)
      - [Success](#success-20)
    - [Case: invalid value for DART file path](#case-invalid-value-for-dart-file-path)
      - [Failure](#failure-20)
- [logger-filename](#logger-filename)
  - [Use Cases](#use-cases-21)
    - [Case: input loger file name](#case-input-loger-file-name)
      - [Success](#success-21)
- [logger-mask](#logger-mask)
- [logsub](#logsub)
- [net-mode](#net-mode)
  - [Use Cases](#use-cases-22)
    - [Case: try different modes](#case-try-different-modes)
      - [Success](#success-22)
    - [Case: run invalid mode](#case-run-invalid-mode)
      - [Failure](#failure-21)
- [p2p-logger](#p2p-logger)
  - [Use Cases](#use-cases-23)
    - [Case: p2p logs](#case-p2p-logs)
      - [Success](#success-23)
- [server-token](#server-token)
- [server-tag](#server-tag)
- [boot](#boot)


# version
```
--version
```
Displays the version of tool

# overwrite
```
--overwrite -O
```
**Refactor**, rename export
Overwrite the config file, to *tagionwave.json* by default
## Use cases
Overwrite file for config to another json file <br>
Overwrite file for config with default tagionwave.json

### Case: overwrite config file

```
tagionwave -O new_config_file.json
```

#### Success

**Result**:<br>
Configure file written to new file
```
Configure file written to new_config_file.json
...
```

### Case: overwrite config file without param

```
tagionwave -O
```
#### Success

**Result**:<br>
Configure file written to default file
```
Configure file written to tagionwave.json
...
```

# transaction-max
```
--transaction-max -D
```
Set the max number of transaction services opened, **mode0 only**

## Use cases
Correct input for transaction-max<br>
Big number input for transaction-max<br>
Negative input for transaction-max

### Case: input max amount of transactions
```
tagionwave -D 0
```

#### Success
**Result**:<br>
Successful network launch

### Case: invalid input
```
tagionwave -D 123456789
```

#### Failure
**Result**:<br>
Output that the input value is too large
```
Overflow in integral conversion
```

### Case: invalid input
```
tagionwave -D -10
```

#### Failure
**Result**:<br>
Negative input
```
Unexpected '-' when converting from type string to type uint
```

# ip
```
--ip
```
Listen for gossip protocol on provided IP, 0.0.0.0 by default for any ip

## Use cases
Correct input for host gossip ip <br>
Empty host gossip ip

### Case: input host gossip ip
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 --ip 127.0.0.1
```

#### Success
**Result**:<br>
Successful network launch with similar output
```
transcript0: Register: transcript0 logger
Register: collector0 logger

collector0: Register: collector0 logger
collector0: SockectThread port=10800 addresss=127.0.0.1
Register: transaction.service0 logger
...
```

### Case: empty host gossip ip
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 --ip
```

#### Failure
**Result**:<br>
Output about the absence of a parameter
```
Missing value for argument --ip.
```

# port  
```
--port
```
Set Host gossip port for node communication, 4001 by default
**Refactor**, exeption

## Use cases
Correct input for host gossip port <br>
Invalid number for host gossip port

### Case: set gossip port
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 
```

#### Success
**Result**:<br>
Successful network launch

### Case: invalid value for gossip port
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=40201222 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
```

#### Failure
**Result**:<br>
Invalid value for port
```
ERROR FROM GO: failed to parse multiaddr "/ip4/0.0.0.0/tcp/40201222": invalid value "40201222" for protocol tcp: failed to parse port addr: greater than 65536
local-tagion:FATAL: From task local-tagion 'InternalError'
local-tagion:FATAL: From task local-tagion 'InternalError'
local-tagion:FATAL: p2p.go_helper.GoException@/home/lokalbruger/work/fixed_tagion/tagion/src/lib-p2pgowrapper/p2p/go_helper.d(31): InternalError

```

# pid
```
--pid
```
Used to write a file with the process ID for the program.

## Use Cases
Input file with extension .pid <br>
Empty file name for pid

### Case: input file for pid
```
tagionwave --pid file_for_pid.pid
```

#### Success
**Result**:<br>
Successful network launch with similar output
```
----- Start tagion service task -----
PID = 141536 written to file_for_pid.pid
...
```

### Case: empty file for pid
```
tagionwave --pid
```

#### Failure
**Result**:<br>
Output about the absence of a parameter
```
Missing value for argument --pid.
```

# nodes
```
--nodes -N
```
Set number of nodes to run network, 4 by default (4 min)

## Use Cases
Set amount of active nodes that >= 4 <br>
Set amount of active nodes that < 4

### Case: set nodes amount
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 5
```

#### Success
**Result**:<br>
Successful network launch with provided nodes number
```
Node_0: Register: Node_0 logger
...

Node_1: Register: Node_1 logger
...

Node_2: Register: Node_2 logger
...

Node_3: Register: Node_3 logger
...

Node_4: Register: Node_4 logger
...
```

### Case: invalid nodes number
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 3
```
#### Failure
**Result**:<br>
Сheck for the number of active nodes does not pass
```
discovery-internal:TRACE: update 1 02a129493216004b
discovery-internal:TRACE: FILE NETWORK READY 5 < 3 (false) done = false
```

# seed
**flag should be deleted**

# timeout
```
--timeout -t
```
The time bewteen empty gossip event generation in the hashgraph(in milliseconds), 3000 by default

## Use Cases
Set time stemp bewteen empty gossip event generation<br>
Set zero timeout bewteen empty gossip event generation

### Case: set timeout
```
tagionwave -t 800
```

#### Success
**Result**:<br>
Successful network launch and similar output

### Case: invalid value for timeout
```
tagionwave -t 0
```

#### Failure
**Result**:<br>
Network does not start with output:
```
ERROR FROM GO: failed to dial QmWaFmTGLEH3MQeGe2ovW7inigt4wMJ4MXdKn7y1ajTL1p:
  * [/ip4/0.0.0.0/tcp/4002] dial backoff
ERROR FROM GO: failed to dial QmXVNLzZesuczSVfms2T6e6qxFi7AHycoMDWtYd2BfZRXn:
  * [/ip4/0.0.0.0/tcp/4003] dial backoff
local-tagion:TRACE: active_nodes=5
ERROR FROM GO: failed to dial QmUV9hHQSWKXYXqmh8iU1h7oiAfJWPK4mb1H7VD5Pxosku:
  * [/ip4/0.0.0.0/tcp/40201] dial tcp4 0.0.0.0:40201: connect: connection refused
```

# delay
**flag should be deleted**

# trace-gossip
**flag should be deleted**

# loops
**flag should be deleted**

# url
**flag should be deleted**

# sockets
```
--sockets -M
```
**Refactor**,  should be rename --monitors
Set the number  max of monitor opened in mode0, is not used in other modes

## Use Cases
Set max number of open monitors<br>
Set a negative maximum number of open monitors

### Case: set max number of open monitors
```
tagionwave -M 10
```

#### Success
**Result**:<br>
Successful network launch

### Case: invalid value
```
tagionwave -M -5
```

#### Failure
**Result**:<br>
Negative input
```
Unexpected '-' when converting from type string to type uint
```

# tmp
```
--tmp
```
Set temporary directory for network, */tmp/* by default, used for temporary files

## Use Cases
Set directory for temporary files<br>
Set empty directory name for temporary files

### Case: input directory for tmp
```
tagionwave --tmp tmp_dir
```

#### Success
**Result**:<br>
Successful network launch and temp files created in tmp_dir

### Case: empty directory name for tmp
```
tagionwave --tmp
```

#### Failure
**Result**:<br>
Output about the absence of a parameter
```
Missing value for argument --tmp.
```


# monitor
```
--monitor -P
```
Set the first monitor port, 10900 by default

## Use cases
Set port for first monitor <br>
Set not valid port for first monitor

### Case: set first monitor port
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 -P 10901
```

#### Success
**Result**:<br>
Successful network launch

### Case: invalid value
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 -P 500
```

#### Failure
**Result**:<br>
TODO Refacor, work correct

# stdout 
**Refactor**, has no affect
```
--stdout
```

# transaction-ip
```
--transaction-ip
```
Set ip for listen transactions, 0.0.0.0 by default

## Use cases
Set transaction ip <br>
Set empty transaction ip

### Case: input transaction ip
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 --transaction-ip 127.0.0.0 
```

#### Success
**Result**:<br>
Successful network launch

### Case: empty transaction ip
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 --transaction-ip
```
#### Failure
**Result**:<br>
Output about the absence of a parameter
```
Missing value for argument --transaction-ip.
```

# transaction-port
```
--transaction-port -p
```
Set port for listen transcation, 10800 by default
**Refactor**, error case

## Use cases
Set correct port<br>
Set wrong port

### Case: set port
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
```

#### Success
**Result**:<br>
Successful network launch and similar output
```
transcript0: Register: transcript0 logger
collector0: Register: collector0 logger
collector0: SockectThread port=10801
...
```

### Case: invalid value for port
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=111111 --logger-filename=./shared/node-1.log -N 4
```

#### Failure
**Result**:<br>
Node will not run

# transaction-queue
```
--transaction-queue
```
Set the max number of listeners in the transaction services, 100 by default

## Use Cases
Set correct amount of max listeners<br>
Set wrong of max listeners<br>

### Case: set max number of listeners
```
tagionwave --transaction-queue 4
```

#### Success
**Result**:<br>
Successful network launch

### Case: invalid value for max number of listeners
```
tagionwave --transaction-queue 4444444444444444
```

#### Failure
**Result**:<br>
Output that the input value is too large
```
Overflow in integral conversion
```

# transaction-maxcon
```
--transaction-maxcon
```
Set maximum number of connections, 1000 by default

## Use Cases
Set correct amount max number of connections<br>
Set wrong amount max number of connections

### Case: set max connections number
```
tagionwave --transaction-maxcon 100
```

#### Success
**Result**:<br>
Successful network launch

### Case: empty value for max connections number
```
tagionwave --transaction-maxcon
```

#### Failure
**Result**:<br>
Output about the absence of a parameter
```
Missing value for argument --transaction-maxcon.
```

# transaction-maxqueue
```
--transaction-maxqueue
```
Set the max number of connection which can be handle by the transaction servives, 100 by default


## Use Cases
Set correct amount max number of connections<br>
Set wrong amount max number of connections

### Case: set max connections number
```
tagionwave --transaction-maxqueue 100
```

#### Success
**Result**:<br>
Successful network launch

### Case: empty value for max connections number
```
tagionwave --transaction-maxqueue
```

#### Failure
**Result**:<br>
Output about the absence of a parameter
```
Missing value for argument --transaction-maxqueue.
```

# epochs
```
--epochs
```
Used in for test and will stop the program when X epochs has been generated, 0 = inf, 0 by default

## Use Cases
Set correct epochs number<br>
Set big epochs number<br>

### Case: set epochs number
```
tagionwave --epochs 100
```

#### Success
**Result**:<br>
Successful network launch

### Case: invalid value for epochs
```
tagionwave --epochs 111111111111
```

#### Failure
**Result**:<br>
Output that the input value is too large
```
Overflow in integral conversion
```
# transcript-from
**flag should be deleted**

# transcript-to
**flag should be deleted**

# transcript-log
```
--transcript-log
```
Set filename for transcript log, *transcript* by default

## Use Cases
Set name for transcript log file<br>
Empty name for transcript log file

### Case: set filename for transcript log
```
tagionwave --transcript-log transcript_new
```

#### Success
**Result**:<br>
Successful network launch with similar output
```
transcript_new0: Register: transcript_new0 logger
collector0: Register: collector0 logger
collector0: SockectThread port=10800 addresss=127.0.0.1
Register: transaction.service0 logger
...
```

### Case: empty input
```
tagionwave --transcript-log
```

#### Failure
**Result**:<br>
Output about the absence of a parameter
```
Missing value for argument --transcript-log.
```

# transcript-debug
**flag should be deleted**

# dart-filename
```
--dart-filename
```
Set DART file name, *./data/%dir%/dart.drt* by default, **refactor**

## Use Cases
Set file name for new DART<br>

### Case: set new DART file name
```
tagionwave --dart-filename new_dart.drt
```

#### Failure
**Result**:<br>
Node will not run
```
ERROR FROM GO: protocol not supported
dart.sync2: Error, connection failed with code: InternalError
dart.sync3: Error, connection failed with code: InternalError
ERROR FROM GO: protocol not supported
Segmentation fault (core dumped)
```

# dart-synchronize
```
--dart-synchronize
```
Use if we need synchronization for dart
**Refactor**

## Use Cases
Synchronize nodes with master node<br>
Wrong input 

### Case: need synchronization
```
tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
```

#### Success
**Result**:<br> 
Successful network launch with similar output
```
dart.sync2: DART initialized with angle: (0, 0)
dart.sync2: DART bullseye: 
dart.sync2: SYNC: true
...
```

### Case: Invalid input for dart-synchronize
```
tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=123 --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
```

### Failure
**Result**:<br>
Network will not run

# dart-angle-from-port
**flag should be deleted**

# dart-master-angle-from-port
**flag should be deleted**

# dart-init
```
--dart-init
```
Initialize empty DART **refactor**

## Use cases
Initialize DART<br>
Wrong input

### Case: init DART
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
```

#### Success
**Result**:<br>
Successful network launch with similar output
```
dart.sync2: DART initialized with angle: (0, 0)
dart.sync2: DART bullseye: 
...
```

### Case: invalid value for dart init
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=0 --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=111111 --logger-filename=./shared/node-1.log -N 4
```

#### Failure
**Result**:<br>
Node will not run

# dart-generate
```
--dart-generate 
```
**flag should be deleted**<br>

# dart-from 
```
--dart-from
```
**flag should be deleted**<br>

# dart-to
```
--dart-to
```
**flag should be deleted**<br>

# dart-request 
**flag should be deleted**

# dart-path
```
--dart-path
```
Set path for DART file

## Use Cases
Set path for DART file<br>
Set path for non-existent file

### Case: set DART file path 
```
tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path ./data/dart1.drt --port=4001 --transaction-port=10801 -N 4
```

#### Success
**Result**:<br>
Successful network launch

### Case: invalid value for DART file path 
```
tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path wizard_file --port=4001 --transaction-port=10801 -N 4
```

#### Failure
**Result**:<br>
Network will not run with output:
```
dart.sync1:FATAL: From task dart.sync1 'Cannot open file `wizard_file1' in mode `w+' (No such file or directory)'
dart.sync1:FATAL: From task dart.sync1 'Cannot open file `wizard_file1' in mode `w+' (No such file or directory)'
...
```

# logger-filename
```
--logger-filename
```
Set logger file name, */tmp/tagion.log* by default 
## Use Cases
Set file for logger

### Case: input loger file name 
```
tagionwave --logger-filename /new_tmp/tagion.log
```
#### Success
**Result**:<br>
Successful network launch and logs are in new_tmp/tagion.log file

# logger-mask 
**flag should be deleted**

# logsub
```
--logsub -L
```
**Refactor**, service not implemented yet<br>
Enables the logger subscription service

# net-mode
```
--net-mode
```
Set mode to the network(internal, local, pub), internal by default

## Use Cases
Run network<br>
Run non-existent mode

### Case: try different modes
```
tagionwave --net-mode internal
tagionwave --net-mode local
tagionwave --net-mode pub
```

#### Success
**Result**:<br>
Successful network launch

### Case: run invalid mode
```
tagionwave --net-mode my_mode
```

#### Failure
**Result**:<br>
Network will not run with output:
```
NetworkMode does not have a member named 'my_mode'
```

# p2p-logger
```
--p2p-logger
```
Enable conssole logs for libp2p, false by default

## Use Cases
Print conssole logs

### Case: p2p logs
```
tagionwave --p2p-logger
```

#### Success
**Result**:<br>
Successful network launch with similar output
```
Node_1: Register: Node_1 logger
Node_1: opts.node_name = Node_1
2022-07-21T14:45:48.167+0300	DEBUG	basichost	basic/basic_host.go:275	failed to fetch local IPv6 address	{"error": "no route found for ::"}
2022-07-21T14:45:48.167+0300	DEBUG	addrutil	go-addr-util@v0.1.0/addr.go:64	adding resolved addr:/ip4/0.0.0.0/tcp/4020 /ip4/192.168.0.112/tcp/4020 [/ip4/192.168.0.112/tcp/4020]
2022-07-21T14:45:48.167+0300	DEBUG	addrutil	go-addr-util@v0.1.0/addr.go:64	adding resolved addr:/ip4/0.0.0.0/tcp/4020 /ip4/127.0.0.1/tcp/4020 [/ip4/192.168.0.112/tcp/4020 /ip4/127.0.0.1/tcp/40
...
```

# server-token
**flag should be deleted**

# server-tag
**flag should be deleted**

# boot
**flag should be deleted**
