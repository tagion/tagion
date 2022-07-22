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

#### [Tool link](https://github.com/tagion/tagion/tree/release/src/bin-wave)

# Table of contents
- [Tagion tool v.x.x.x](#tagion-tool-vxxx)
      - [Tool link](#tool-link)
- [Table of contents](#table-of-contents)
- [version](#version)
- [overwrite (Refactor, export)](#overwrite-refactor-export)
  - [Use cases](#use-cases)
    - [Case: overwrire config file](#case-overwrire-config-file)
      - [Success](#success)
      - [Success](#success-1)
- [transaction-max (TODO, only for mode1)](#transaction-max-todo-only-for-mode1)
  - [Use cases](#use-cases-1)
    - [Case: input max amout of transactions](#case-input-max-amout-of-transactions)
      - [Success](#success-2)
      - [Failure](#failure)
    - [Case: negative input](#case-negative-input)
      - [Failure](#failure-1)
- [ip](#ip)
  - [Use cases](#use-cases-2)
    - [Case: input host gossip ip](#case-input-host-gossip-ip)
      - [Success](#success-3)
      - [Failure](#failure-2)
- [port (TODO, only for mode1)](#port-todo-only-for-mode1)
- [pid](#pid)
  - [Use Cases](#use-cases-3)
    - [Case: input file for pid](#case-input-file-for-pid)
      - [Success](#success-4)
      - [Failure](#failure-3)
- [nodes](#nodes)
  - [Use Cases](#use-cases-4)
    - [Case: set nodes amount](#case-set-nodes-amount)
      - [Success](#success-5)
      - [Failure](#failure-4)
- [seed (not use anymore))](#seed-not-use-anymore)
- [timeout](#timeout)
  - [Use Cases](#use-cases-5)
    - [Case: set nodes amount](#case-set-nodes-amount-1)
      - [Success](#success-6)
      - [Failure](#failure-5)
- [delay (not use anymore)](#delay-not-use-anymore)
- [trace-gossip (not use anymore)](#trace-gossip-not-use-anymore)
- [loops (not use anymore)](#loops-not-use-anymore)
- [url (not use anymore)](#url-not-use-anymore)
- [sockets](#sockets)
- [tmp](#tmp)
  - [Use Cases](#use-cases-6)
    - [Case: input file for pid](#case-input-file-for-pid-1)
      - [Success](#success-7)
      - [Failure](#failure-6)
- [monitor (TODO, only for mode1)](#monitor-todo-only-for-mode1)
- [stdout (TODO, Refactor, has no affect)](#stdout-todo-refactor-has-no-affect)
- [transaction-ip (TODO, only for mode1)](#transaction-ip-todo-only-for-mode1)
- [transaction-port (TODO, only for mode1)](#transaction-port-todo-only-for-mode1)
- [transaction-queue](#transaction-queue)
  - [Use Cases](#use-cases-7)
    - [Case: set max number of listeners](#case-set-max-number-of-listeners)
      - [Success](#success-8)
      - [Failure](#failure-7)
- [transaction-maxcon](#transaction-maxcon)
  - [Use Cases](#use-cases-8)
    - [Case: set max connections number](#case-set-max-connections-number)
      - [Success](#success-9)
      - [Failure](#failure-8)
- [transaction-maxqueue](#transaction-maxqueue)
  - [Use Cases](#use-cases-9)
    - [Case: set max connections number](#case-set-max-connections-number-1)
      - [Success](#success-10)
      - [Failure](#failure-9)
- [epochs](#epochs)
  - [Use Cases](#use-cases-10)
    - [Case: set max connections number](#case-set-max-connections-number-2)
      - [Success](#success-11)
      - [Failure](#failure-10)
- [transcript-from (not used anymore)](#transcript-from-not-used-anymore)
- [transcript-to (not used anymore)](#transcript-to-not-used-anymore)
- [transcript-log (TODO, only for mode1)](#transcript-log-todo-only-for-mode1)
- [transcript-debug (not used anymore)](#transcript-debug-not-used-anymore)
- [dart-filename (TODO, Refactor)](#dart-filename-todo-refactor)
  - [Use Cases](#use-cases-11)
    - [Case: set new DART file name](#case-set-new-dart-file-name)
      - [Failure](#failure-11)
- [dart-synchronize](#dart-synchronize)
  - [Use Cases](#use-cases-12)
    - [Case: need synchronization](#case-need-synchronization)
      - [Success](#success-12)
- [dart-angle-from-port (not used anymore)](#dart-angle-from-port-not-used-anymore)
- [dart-master-angle-from-port (not used anymore)](#dart-master-angle-from-port-not-used-anymore)
- [dart-init](#dart-init)
  - [Use Cases](#use-cases-13)
    - [Case: generate block file](#case-generate-block-file)
      - [Success](#success-13)
- [dart-generate dart path (not used anymore)](#dart-generate-dart-path-not-used-anymore)
  - [Use Cases](#use-cases-14)
    - [Case: generate owerwrite DART file](#case-generate-owerwrite-dart-file)
      - [Success](#success-14)
- [dart-from](#dart-from)
- [dart-to](#dart-to)
- [dart-request (not use anymore)](#dart-request-not-use-anymore)
- [dart-path  (Refactor exeption)](#dart-path--refactor-exeption)
  - [Use Cases](#use-cases-15)
    - [Case: set DART file path](#case-set-dart-file-path)
      - [Success](#success-15)
      - [Failure](#failure-12)
- [logger-filename](#logger-filename)
  - [Use Cases](#use-cases-16)
    - [Case: loger file name](#case-loger-file-name)
      - [Success](#success-16)
- [logger-mask (not use anymore)](#logger-mask-not-use-anymore)
- [logsub (Refactor, service not implemented yet)](#logsub-refactor-service-not-implemented-yet)
  - [Use Cases](#use-cases-17)
    - [Case: enables the logger subscription service](#case-enables-the-logger-subscription-service)
      - [Success](#success-17)
- [net-mode](#net-mode)
  - [Use Cases](#use-cases-18)
    - [Case: try different modes](#case-try-different-modes)
      - [Success](#success-18)
      - [Failure](#failure-13)
- [p2p-logger](#p2p-logger)
  - [Use Cases](#use-cases-19)
    - [Case: p2p logs](#case-p2p-logs)
      - [Success](#success-19)
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
./tagionwave -O new_config_file.json
```
**Result**:<br>
```
Configure file written to new_config_file.json
...
```
#### Success
```
./tagionwave -O
```
**Result**:<br>
```
Configure file written to tagionwave.json
```

# transaction-max (TODO, only for mode1)
```
--transaction-max -D
```
Set number of monitors to display

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

# port (TODO, only for mode1)
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

# nodes
```
--nodes -N
```
Set number of nodes to run network, 4 by default

## Use Cases

### Case: set nodes amount

#### Success
```
./tagionwave -N 10
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
```
ls data/
node0  node1  node2  node3  node4  node5  node6  node7  node8  node9
```
#### Failure
```
./tagionwave -N -4
```
**Result**:<br>
```
Unexpected '-' when converting from type string to type uint
```

# seed (not use anymore))

# timeout
```
--timeout -t
```
The time bewteen empty gossip event generation in the hashgraph(in milliseconds)

## Use Cases

### Case: set nodes amount

#### Success
```
./tagionwave -t 800
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
./tagionwave -t -100
```
**Result**:<br>
```
Unexpected '-' when converting from type string to type uint
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

# tmp
```
--tmp
```
Set temporary directory for network, */tmp/* by default

## Use Cases

### Case: input file for pid

#### Success
```
./tagionwave --tmp tmp_dir
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
./tagionwave --tmp
```
**Result**:<br>
```
Missing value for argument --tmp.
```


# monitor (TODO, only for mode1)
```
--monitor -P
```
Set the first monitor port (port>=6000), 10900 by default

# stdout (TODO, Refactor, has no affect)
```
--stdout
```

# transaction-ip (TODO, only for mode1)
```
--transaction-ip
```
Set ip for listen transactions, 0.0.0.0 by default

# transaction-port (TODO, only for mode1)
```
--transaction-port -p
```
Set port for listen transcation, 10800 by default

# transaction-queue
```
--transaction-queue
```
Set the max number of listeners in the transaction services
## Use Cases

### Case: set max number of listeners

#### Success
```
./tagionwave --transaction-queue 4
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
./tagionwave --transaction-queue 4444444444444444
```
**Result**:<br>
```
Overflow in integral conversion
```

# transaction-maxcon
```
--transaction-maxcon
```
Set maximum number of connections, 1000 by default

## Use Cases

### Case: set max connections number

#### Success
```
./tagionwave --transaction-maxcon 100
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
./tagionwave --transaction-maxcon
```
**Result**:<br>
```
Missing value for argument --transaction-maxcon.
```


# transaction-maxqueue
```
--transaction-maxqueue
```
Set the max number of connection which can be handle by the transaction servives

## Use Cases

### Case: set max connections number

#### Success
```
./tagionwave --transaction-maxqueue 100
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
./tagionwave --transaction-maxqueue 999999999999
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
./tagionwave --epochs 100
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
./tagionwave --epochs 111111111111
```
**Result**:<br>
```
Overflow in integral conversion
```
# transcript-from (not used anymore)

# transcript-to (not used anymore)

# transcript-log (TODO, only for mode1)
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
./tagionwave --dart-filename new_dart.drt
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

## Use Cases

### Case: need synchronization

#### Success
```
./tagionwave --dart-synchronize
```
**Result**:<br> TODO
```
----- Start tagion service task -----
Waiting for logger
REGISTER logger
Logger started
Register: tagionwave logger
...
```

# dart-angle-from-port (not used anymore)

# dart-master-angle-from-port (not used anymore)

# dart-init
```
--dart-init
```
Initialize empty DART
## Use Cases

### Case: generate block file

#### Success
```
./tagionwave --dart-init
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

# dart-generate dart path (not used anymore)
```
--dart-generate 
```
Generate dart with random data, use if you did not done precondition or you will owerwrite Dart file. <br>
If you want to set path for dart, use
```
./tagionwave --dart-generate --dart-path your_path
```
## Use Cases

### Case: generate owerwrite DART file

#### Success
```
./tagionwave --dart-generate
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

# dart-from
```
--dart-from
```
TODO

# dart-to
```
--dart-to
```
TODO

# dart-request (not use anymore)

# dart-path  (Refactor exeption)
```
--dart-path
```
Set path for DART file

## Use Cases

### Case: set DART file path 

#### Success
```
./tagionwave --dart-path /data/node0
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
./tagionwave --dart-path qweqweqweq
```
**Result**:<br>
```
ERROR FROM GO: protocol not supported
ERROR FROM GO: protocol not supported
ERROR FROM GO: protocol not supported
ERROR FROM GO: protocol not supported
ERROR FROM GO: protocol not supported
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
./tagionwave --logger-filename /new_tmp/tagion.log
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
./tagionwave -L
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
./tagionwave --net-mode internal
./tagionwave --net-mode local
./tagionwave --net-mode pub
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
./tagionwave --net-mode my_mode
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
./tagionwave --p2p-logger
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

