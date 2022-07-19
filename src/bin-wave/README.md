<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# Tagion tool v.x.x.x
> Brief tools description.
> The main binary file starts the 'main-node.' The 'main node' connects to the network, runs the hachgraph, and synchronizes the data. It is a full-fledged network node that can be used for operations with tagions, balance checking, etc.
>
#### [Tool link](https://github.com/tagion/tagion/tree/release/src/bin-wave)

- [Tagion tool v.x.x.x](#tagion-tool-vxxx)
      - [Tool link](#tool-link)
- [version](#version)
- [overwrite](#overwrite)
- [transaction-max](#transaction-max)
  - [Use cases 1](#use-cases-1)
    - [Case 1 1](#case-1-1)
      - [Success 1 1](#success-1-1)
      - [Failure 1 1](#failure-1-1)
    - [Case 1 2](#case-1-2)
      - [Failure 1 1](#failure-1-1-1)


# version
```
./tagionwave --version
```
Displays the version of tool

# overwrite
```
./tagionwave -O
```
Overwrite the config file, to *tagionwave,json* by default

# transaction-max
```
./tagionwave -D 0
```
Transaction max = 0 means all nodes: default 0

## Use cases 1

### Case 1 1
Input corect and incorect data for transaction max

#### Success 1 1

**Result**:<br>
```
----- Start tagion service task -----
Waiting for logger
REGISTER logger
Logger started
Register: tagionwave logger
...
```
#### Failure 1 1
**Result**:<br>
Big int input
```
Overflow in integral conversion
```

### Case 1 2
Negative input

#### Failure 1 1
**Result**:<br>
```
Unexpected '-' when converting from type string to type uint
```