<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# Tagion tool v.x.x.x
> Brief tools description.
> The main binary file starts the 'main-node.' The 'main node' connects to the network, runs the hachgraph, and synchronizes the data. It is a full-fledged network node that can be used for operations with tagions, balance checking, etc. <br>
> To run network in mode0, you need to follow the instructions below:<br>

```
mkdir data
cd data
mkdir node0
mkdir node1
mkdir node2
mkdir node3
cd ..
./dartutil --initialize --dartfilename dart.drt
mv dart.drt data/node0/
./tagionwave 
```
It will generate config file, than stop tagionwave

> Open *tagionwave.json* and set:<br>
>  "initialize": false<br>
> "synchronize": true <br>
> "net_mode": "internal"
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
> To run network in mode1, you need to follow the instructions below:<br>
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
rm -f ./shared/* ????? node creationt + amaster node + link ????????? + link to req
gnome-terminal --tab -- tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4

gnome-terminal --tab -- tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart2.drt --port=4002 --transaction-port=10802 --logger-filename=./shared/node-2.log -N 4

gnome-terminal --tab -- tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart3.drt --port=4003 --transaction-port=10803 --logger-filename=./shared/node-3.log -N 4

gnome-terminal --tab -- tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=false --dart-synchronize=false --dart-path=./data/dart.drt --port=4020 --transaction-port=10820 --logger-filename=./shared/node-master.log -N 4
```

#### [Tool link](https://github.com/tagion/tagion/tree/release/src/bin-wave)

# Table of contents
- [Tagion tool v.x.x.x](#tagion-tool-vxxx)
  - [> "net_mode": "internal"](#-net_mode-internal)
      - [Tool link](#tool-link)
- [Table of contents](#table-of-contents)
- [version](#version)
- [overwrite (Refactor, export)](#overwrite-refactor-export)
  - [Use cases](#use-cases)
    - [Case: overwrire config file](#case-overwrire-config-file)
      - [Success](#success)
      - [Success](#success-1)
- [transaction-max (only for mode0)](#transaction-max-only-for-mode0)
  - [Use cases](#use-cases-1)
    - [Case: input max amout of transactions](#case-input-max-amout-of-transactions)
      - [Success](#success-2)
      - [Failure](#failure)
    - [Case: negative input](#case-negative-input)
      - [Failure](#failure-1)
- [ip](#ip)
  - [Parameters](#parameters)
  - [Use cases](#use-cases-2)
    - [Case: input host gossip ip](#case-input-host-gossip-ip)
      - [Success](#success-3)
      - [Failure](#failure-2)
- [port](#port)
  - [Parameters](#parameters-1)
  - [Use cases](#use-cases-3)
    - [Case: set gossip port](#case-set-gossip-port)
      - [Success](#success-4)
      - [Failure](#failure-3)
- [pid](#pid)
  - [Use Cases](#use-cases-4)
    - [Case: input file for pid](#case-input-file-for-pid)
      - [Success](#success-5)
      - [Failure](#failure-4)
- [nodes](#nodes)
  - [Use Cases](#use-cases-5)
    - [Case: set nodes amount](#case-set-nodes-amount)
      - [Success](#success-6)
      - [Failure](#failure-5)
- [seed (not use anymore))](#seed-not-use-anymore)
- [timeout ???? def](#timeout--def)
  - [Use Cases](#use-cases-6)
    - [Case: set timeout](#case-set-timeout)
      - [Success](#success-7)
      - [Failure](#failure-6)
- [delay (not use anymore)](#delay-not-use-anymore)
- [trace-gossip (not use anymore)](#trace-gossip-not-use-anymore)
- [loops (not use anymore)](#loops-not-use-anymore)
- [url (not use anymore)](#url-not-use-anymore)
- [sockets](#sockets)
  - [Use Cases](#use-cases-7)
    - [Case: set max number openes monitors number](#case-set-max-number-openes-monitors-number)
      - [Success](#success-8)
      - [Failure](#failure-7)
- [tmp](#tmp)
  - [Use Cases](#use-cases-8)
    - [Case: input file for pid](#case-input-file-for-pid-1)
      - [Success](#success-9)
      - [Failure](#failure-8)
- [monitor](#monitor)
  - [Parameters](#parameters-2)
  - [Use cases](#use-cases-9)
    - [Case: set first monitor port](#case-set-first-monitor-port)
      - [Success](#success-10)
      - [Failure](#failure-9)
- [stdout (TODO, Refactor, has no affect)](#stdout-todo-refactor-has-no-affect)
- [transaction-ip (ask)](#transaction-ip-ask)
- [transaction-port](#transaction-port)
  - [Parameters](#parameters-3)
  - [Use cases](#use-cases-10)
    - [Case: set port](#case-set-port)
      - [Success](#success-11)
      - [Failure](#failure-10)
- [transaction-queue (Refactor, ask, used only for test?)](#transaction-queue-refactor-ask-used-only-for-test)
  - [Use Cases](#use-cases-11)
    - [Case: set max number of listeners](#case-set-max-number-of-listeners)
      - [Success](#success-12)
      - [Failure](#failure-11)
- [transaction-maxcon(Refactor, ask, used only for test?)](#transaction-maxconrefactor-ask-used-only-for-test)
  - [Use Cases](#use-cases-12)
    - [Case: set max connections number](#case-set-max-connections-number)
      - [Success](#success-13)
      - [Failure](#failure-12)
- [transaction-maxqueue (Refactor, ask, used only for test?)](#transaction-maxqueue-refactor-ask-used-only-for-test)
  - [Use Cases](#use-cases-13)
    - [Case: set max connections number](#case-set-max-connections-number-1)
      - [Success](#success-14)
      - [Failure](#failure-13)
- [epochs](#epochs)
  - [Use Cases](#use-cases-14)
    - [Case: set max connections number](#case-set-max-connections-number-2)
      - [Success](#success-15)
      - [Failure](#failure-14)
- [transcript-from (not used anymore)](#transcript-from-not-used-anymore)
- [transcript-to (not used anymore)](#transcript-to-not-used-anymore)
- [transcript-log (??????)](#transcript-log-)
- [transcript-debug (not used anymore)](#transcript-debug-not-used-anymore)
- [dart-filename (TODO, Refactor)](#dart-filename-todo-refactor)
  - [Use Cases](#use-cases-15)
    - [Case: set new DART file name](#case-set-new-dart-file-name)
      - [Failure](#failure-15)
- [dart-synchronize](#dart-synchronize)
  - [Parameters](#parameters-4)
  - [Use Cases](#use-cases-16)
    - [Case: need synchronization](#case-need-synchronization)
      - [Success](#success-16)
    - [Failure](#failure-16)
- [dart-angle-from-port (not used anymore)](#dart-angle-from-port-not-used-anymore)
- [dart-master-angle-from-port (not used anymore)](#dart-master-angle-from-port-not-used-anymore)
- [dart-init](#dart-init)
  - [Parameters](#parameters-5)
  - [Use cases](#use-cases-17)
    - [Case: init DART](#case-init-dart)
      - [Success](#success-17)
      - [Failure](#failure-17)
- [dart-generate dart path (not used anymore)](#dart-generate-dart-path-not-used-anymore)
  - [Use Cases](#use-cases-18)
    - [Case: generate owerwrite DART file](#case-generate-owerwrite-dart-file)
      - [Success](#success-18)
- [dart-from (ask, delete?)](#dart-from-ask-delete)
- [dart-to (ask, delete?)](#dart-to-ask-delete)
- [dart-request (not use anymore)](#dart-request-not-use-anymore)
- [dart-path](#dart-path)
  - [Use Cases](#use-cases-19)
    - [Case: set DART file path](#case-set-dart-file-path)
      - [Success](#success-19)
      - [Failure](#failure-18)
- [logger-filename](#logger-filename)
  - [Use Cases](#use-cases-20)
    - [Case: loger file name](#case-loger-file-name)
      - [Success](#success-20)
- [logger-mask (not use anymore)](#logger-mask-not-use-anymore)
- [logsub (Refactor, service not implemented yet)](#logsub-refactor-service-not-implemented-yet)
  - [Use Cases](#use-cases-21)
    - [Case: enables the logger subscription service](#case-enables-the-logger-subscription-service)
      - [Success](#success-21)
- [net-mode](#net-mode)
  - [Use Cases](#use-cases-22)
    - [Case: try different modes](#case-try-different-modes)
      - [Success](#success-22)
      - [Failure](#failure-19)
- [p2p-logger](#p2p-logger)
  - [Use Cases](#use-cases-23)
    - [Case: p2p logs](#case-p2p-logs)
      - [Success](#success-23)
- [server-token (not used anymore)](#server-token-not-used-anymore)
- [server-tag (not use anymore)](#server-tag-not-use-anymore)
- [boot (not use anymore)](#boot-not-use-anymore)


# version
```
--version
```
Displays the version of tool

# overwrite (Refactor, export)
```
--owerwrite -O
```
Overwrite the config file, to *tagionwave,json* by default
## Use cases

### Case: overwrire config file

#### Success
```
tagionwave -O new_config_file.json
```
**Result**:<br>
```
Configure file written to new_config_file.json
...
```
#### Success
```
tagionwave -O
```
**Result**:<br>
```
Configure file written to tagionwave.json
```

# transaction-max (only for mode0)
```
--transaction-max -D
```
Set the max number of transaction services opened in mode0 only

## Use cases

### Case: input max amout of transactions

#### Success
```
tagionwave -D 0
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
tagionwave -D 123456789
```
**Result**:<br>
```
Overflow in integral conversion
```
### Case: negative input

#### Failure
```
tagionwave -D -10
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

## Parameters

[--boot](#boot) **required** (Set boot.hibon file)

[--port](#port) **required** (Set port gor host gossip ip)

[--dart-init](#dart-init) **required** (Init empty DART)

[--net-mode](#net-mode) **required** (Set mode for network)

[--dart-synchronize](#dart-synchronize) **required** (Regular node should be synchronize, and not synchronize for master node)

[--dart-path](#dart-path) **required** (Set path for DART file)

[--transaction-port](#transaction-port) (Set port for transactions)

[--logger-filename](#logger-filename) (Set file for logs)

## Use cases

### Case: input host gossip ip


#### Success
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 --ip 127.0.0.0 
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
Empty ip
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 --ip
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
## Parameters

[--boot](#boot) **required** (Set boot.hibon file)

[--dart-init](#dart-init) **required** (Init empty DART)

[--net-mode](#net-mode) **required** (Set mode for network)

[--dart-synchronize](#dart-synchronize) **required** (Regular node should be synchronize, and not synchronize for master node)

[--dart-path](#dart-path) **required** (Set path for DART file)

[--transaction-port](#transaction-port) (Set port for transactions)

[--logger-filename](#logger-filename) (Set file for logs)

## Use cases

### Case: set gossip port

#### Success
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 
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
Wrong port
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=40201222 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
```
**Result**:<br>
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
Write Process IDentificator to input file

## Use Cases

### Case: input file for pid

#### Success
```
tagionwave --pid file_for_pid
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
No name for file for pid
```
tagionwave --pid
```
**Result**:<br>
```
Missing value for argument --pid.
```

# nodes
```
--nodes -N
```
Set number of nodes to run network, 4 by default

## Use Cases

### Case: set nodes amount

#### Success
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
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
Not enough nodes
```
tagionwave -N 3
```
**Result**:<br>
```
discovery-internal:TRACE: update 1 02a129493216004b
discovery-internal:TRACE: FILE NETWORK READY 5 < 3 (false) done = false
```

# seed (not use anymore))

# timeout ???? def
```
--timeout -t
```
The time bewteen empty gossip event generation in the hashgraph(in milliseconds)

## Use Cases

### Case: set timeout

#### Success
```
tagionwave -t 800
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
Wrong value for timeout
```
tagionwave -t 0
```
**Result**:<br>
```
ERROR FROM GO: failed to dial QmWaFmTGLEH3MQeGe2ovW7inigt4wMJ4MXdKn7y1ajTL1p:
  * [/ip4/0.0.0.0/tcp/4002] dial backoff
ERROR FROM GO: failed to dial QmXVNLzZesuczSVfms2T6e6qxFi7AHycoMDWtYd2BfZRXn:
  * [/ip4/0.0.0.0/tcp/4003] dial backoff
local-tagion:TRACE: active_nodes=5
ERROR FROM GO: failed to dial QmUV9hHQSWKXYXqmh8iU1h7oiAfJWPK4mb1H7VD5Pxosku:
  * [/ip4/0.0.0.0/tcp/40201] dial tcp4 0.0.0.0:40201: connect: connection refused
```

# delay (not use anymore)

# trace-gossip (not use anymore)

# loops (not use anymore)

# url (not use anymore)

# sockets
```
--sockets -M (Refactor,  should be rename --monitors)
```
Set the number  max of monitor opened in mode0, is not used in other modes

## Use Cases

### Case: set max number openes monitors number

#### Success
```
tagionwave -M 10
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
Wrong num of max monitors
```
tagionwave -M -5
```
**Result**:<br>
```
Unexpected '-' when converting from type string to type uint
```

# tmp
```
--tmp
```
Set temporary directory for network, */tmp/* by default

## Use Cases

### Case: input file for pid

#### Success
```
tagionwave --tmp tmp_dir
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
tagionwave --tmp
```
**Result**:<br>
```
Missing value for argument --tmp.
```


# monitor
```
--monitor -P
```
Set the first monitor port (port>=6000), 10900 by default

## Parameters

[--boot](#boot) **required** (Set boot.hibon file)

[--port](#port) **required** (Set port gor host gossip ip)

[--dart-init](#dart-init) **required** (Init empty DART)

[--net-mode](#net-mode) **required** (Set mode for network)

[--dart-synchronize](#dart-synchronize) **required** (Regular node should be synchronize, and not synchronize for master node)

[--dart-path](#dart-path) **required** (Set path for DART file)

[--transaction-port](#transaction-port) **required** (Set port for transactions)

[--logger-filename](#logger-filename) **optional** (Set file for logs)

## Use cases

### Case: set first monitor port


#### Success
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 -P 10901
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
Wrong port
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4 -P 500
```
**Result**:<br>
TODO Refacor, work correct

# stdout (TODO, Refactor, has no affect)
```
--stdout
```

# transaction-ip (ask)
```
--transaction-ip
```
Set ip for listen transactions, 0.0.0.0 by default

# transaction-port
```
--transaction-port -p
```
Set port for listen transcation, 10800 by default

## Parameters

[--boot](#boot) **required** (Set boot.hibon file)

[--port](#port) **required** (Set port gor host gossip ip)

[--dart-init](#dart-init) **required** (Init empty DART)

[--net-mode](#net-mode) **required** (Set mode for network)

[--dart-synchronize](#dart-synchronize) **required** (Regular node should be synchronize, and not synchronize for master node)

[--dart-path](#dart-path) **required** (Set path for DART file)

[--logger-filename](#logger-filename) **optional** (Set file for logs)

## Use cases

### Case: set port


#### Success
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
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
Wrong port
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=111111 --logger-filename=./shared/node-1.log -N 4
```
**Result**:<br>
Node will not run

# transaction-queue (Refactor, ask, used only for test?)
```
--transaction-queue
```
Set the max number of listeners in the transaction services
## Use Cases

### Case: set max number of listeners

#### Success
```
tagionwave --transaction-queue 4
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
tagionwave --transaction-queue 4444444444444444
```
**Result**:<br>
```
Overflow in integral conversion
```

# transaction-maxcon(Refactor, ask, used only for test?)
```
--transaction-maxcon
```
Set maximum number of connections, 1000 by default

## Use Cases

### Case: set max connections number

#### Success
```
tagionwave --transaction-maxcon 100
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
tagionwave --transaction-maxcon
```
**Result**:<br>
```
Missing value for argument --transaction-maxcon.
```


# transaction-maxqueue (Refactor, ask, used only for test?)
```
--transaction-maxqueue
```
Set the max number of connection which can be handle by the transaction servives

## Use Cases

### Case: set max connections number

#### Success
```
tagionwave --transaction-maxqueue 100
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
tagionwave --transaction-maxqueue 999999999999
```
**Result**:<br>
```
Overflow in integral conversion
```

# epochs
```
--epochs
```
Used in for test and will stop the program when X epochs has been generated

## Use Cases

### Case: set max connections number

#### Success
```
tagionwave --epochs 100
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
tagionwave --epochs 111111111111
```
**Result**:<br>
```
Overflow in integral conversion
```
# transcript-from (not used anymore)

# transcript-to (not used anymore)

# transcript-log (??????)
```
--transcript-log
```
Set filename for transcript log, *transcript* by default

# transcript-debug (not used anymore)

# dart-filename (TODO, Refactor)
```
--dart-filename
```
Set DART file name, *./data/%dir%/dart.drt* by default

## Use Cases

### Case: set new DART file name

#### Failure
```
tagionwave --dart-filename new_dart.drt
```
**Result**:<br>
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

## Parameters

[--boot](#boot) **required** (Set boot.hibon file)

[--port](#port) **required** (Set port gor host gossip ip)

[--dart-init](#dart-init) **required** (Init empty DART)

[--net-mode](#net-mode) **required** (Set mode for network)

[--dart-path](#dart-path) **required** (Set path for DART file)

[--transaction-port](#transaction-port) **required**  (Set port for transactions)

[--logger-filename](#logger-filename) **optional** (Set file for logs)

## Use Cases

### Case: need synchronization

#### Success
```
tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
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

### Failure
Wrong value for dart-synchronize
```
tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=123 --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
```
**Result**:<br>
Network will nor run

# dart-angle-from-port (not used anymore)

# dart-master-angle-from-port (not used anymore)

# dart-init
```
--dart-init
```
Initialize empty DART
## Parameters

[--boot](#boot) **required** (Set boot.hibon file)

[--port](#port) **required** (Set port gor host gossip ip)

[--net-mode](#net-mode) **required** (Set mode for network)

[--dart-synchronize](#dart-synchronize) **required** (Regular node should be synchronize, and not synchronize for master node)

[--dart-path](#dart-path) **required** (Set path for DART file)

[--transaction-port](#transaction-port) **required**  (Set port for transactions)

[--logger-filename](#logger-filename) **optional** (Set file for logs)

## Use cases

### Case: init DART


#### Success
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 --logger-filename=./shared/node-1.log -N 4
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
Wrong param for dart init
```
--net-mode=local --boot=./shared/boot.hibon --dart-init=0 --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=111111 --logger-filename=./shared/node-1.log -N 4
```
**Result**:<br>
Node will not run

# dart-generate dart path (not used anymore)
```
--dart-generate 
```
Generate dart with random data, use if you did not done precondition or you will owerwrite Dart file. <br>
If you want to set path for dart, use
```
tagionwave --dart-generate --dart-path your_path
```
## Use Cases

### Case: generate owerwrite DART file

#### Success
```
tagionwave --dart-generate
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

# dart-from (ask, delete?)
```
--dart-from
```
Sets _from_ sector angle for DART in range 0:65535.<br>
This meant to support sharding of the DART but now it's not fully supported yet.<br>

**Refactor** add assertion and text message that this feature not supported yet

Values when `from == to` means full.<br>
Default value: `0`

In development.

# dart-to (ask, delete?)
```
--dart-to
```
Sets _to_ sector angle for DART in range 0:65535.<br>
This meant to support sharding of the DART but now it's not fully supported yet.<br>

**Refactor** add assertion and text message that this feature not supported yet

Values when `from == to` means full.<br>
Default value: `0`

In development.

# dart-request (not use anymore)

# dart-path
```
--dart-path
```
Set path for DART file

[--boot](#boot) **required** (Set boot.hibon file)

[--port](#port) **required** (Set port gor host gossip ip)

[--dart-init](#dart-init) **required** (Init empty DART)

[--net-mode](#net-mode) **required** (Set mode for network)

[--dart-synchronize](#dart-synchronize) **required** (Regular node should be synchronize, and not synchronize for master node)

[--transaction-port](#transaction-port) **required** (Set port for transactions)

[--logger-filename](#logger-filename) **optional** (Set file for logs)

## Use Cases

### Case: set DART file path 

#### Success
```
tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=./data/dart1.drt --port=4001 --transaction-port=10801 -N 4
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
Wrong path
```
tagionwave --net-mode=local --boot=./shared/boot.hibon --dart-init=true --dart-synchronize=true --dart-path=qwe --port=4001 --transaction-port=10801 -N 4
```
**Result**:<br>
```
ERROR FROM GO: protocol not supported
dart.sync: Error, connection failed with code: InternalError
ERROR FROM GO: protocol not supported
Segment Fault
...
```

# logger-filename
```
--logger-filename
```
Set logger file name, */tmp/tagion.log* by default 
## Use Cases

### Case: loger file name 

#### Success
```
tagionwave --logger-filename /new_tmp/tagion.log
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

# logger-mask (not use anymore)

# logsub (Refactor, service not implemented yet)
```
--logsub -L
```
Enables the logger subscription service

## Use Cases

### Case: enables the logger subscription service

#### Success
```
tagionwave -L
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

# net-mode
```
--net-mode
```
Set mode to the network(internal, local, pub), internal by default

## Use Cases

### Case: try different modes


#### Success
```
tagionwave --net-mode internal
tagionwave --net-mode local
tagionwave --net-mode pub
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
tagionwave --net-mode my_mode
```
**Result**:<br>
```
NetworkMode does not have a member named 'my_mode'
```


# p2p-logger
```
--p2p-logger
```
Enable conssole logs for libp2p, false by default

## Use Cases

### Case: p2p logs

#### Success
```
tagionwave --p2p-logger
```
**Result**:<br>
```
Node_1: Register: Node_1 logger
Node_1: opts.node_name = Node_1
2022-07-21T14:45:48.167+0300	DEBUG	basichost	basic/basic_host.go:275	failed to fetch local IPv6 address	{"error": "no route found for ::"}
2022-07-21T14:45:48.167+0300	DEBUG	addrutil	go-addr-util@v0.1.0/addr.go:64	adding resolved addr:/ip4/0.0.0.0/tcp/4020 /ip4/192.168.0.112/tcp/4020 [/ip4/192.168.0.112/tcp/4020]
2022-07-21T14:45:48.167+0300	DEBUG	addrutil	go-addr-util@v0.1.0/addr.go:64	adding resolved addr:/ip4/0.0.0.0/tcp/4020 /ip4/127.0.0.1/tcp/4020 [/ip4/192.168.0.112/tcp/4020 /ip4/127.0.0.1/tcp/40
...
```

# server-token (not used anymore)

# server-tag (not use anymore)

# boot (not use anymore)

