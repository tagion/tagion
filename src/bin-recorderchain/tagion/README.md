<a href="https://tagion.org"><img alt="tagion logo" src="https://github.com/tagion/resources/raw/master/branding/logomark.svg?sanitize=true" alt="tagion.org" height="60"></a>
# recorderchain v.0.x.x
> This tool is used for replay whole recorder chain in DART database. 3 required parameters must be specified.
>- [recorderchain v.0.x.x](#recorderchain-v0xx)
      - [Tool link](#tool-link)
#### [Tool link](https://github.com/tagion/tagion/tree/release/src/bin-boot)

# Table of context
- [recorderchain v.0.x.x](#recorderchain-v0xx)
      - [Tool link](#tool-link)
- [Table of context](#table-of-context)
- [chain_directory](#chain_directory)
  - [Use cases](#use-cases)
    - [Case - set chain directory](#case---set-chain-directory)
      - [Success](#success)
      - [Failure](#failure)
- [dart_file](#dart_file)
  - [Use cases](#use-cases-1)
    - [Case - set dart file directory](#case---set-dart-file-directory)
      - [Success](#success-1)
      - [Failure](#failure-1)
- [initialize](#initialize)

# chain_directory
```
--chain_directory -c
```
*Require* 
Directory that contains recorder block chain

## Use cases
### Case - set chain directory
```
./recorderchain -c /test_chain/TMPFILE -d /test_chain/DARTNEW
```
#### Success
**Result**
New DART database initialized and synchronized with recorder blocks

#### Failure
Comand line output
```
bash: ./recorderchain: No such file or directory
```

# dart_file
```
--dart_file -d
```
*Require* 
Path to dart file

## Use cases
### Case - set dart file directory
```
./recorderchain -c test_chain/TMPFILE -d test_chain/DARTNEW --initialize=true
```
#### Success
**Result**
DART database synchronized with recorder blocks

#### Failure
Comand line output
```
bash: ./recorderchain: No such file or directory
```

# initialize
```
--initialize -i
```
*Require*
Bool, initialize empty DART