- [BDD documentation](#bdd-documentation)
- [List of BDDs](#list-of-bdds)
  - [Structure](#structure)
  - [Commands](#commands)
    - [Help](#help)
    - [See all bdd-targets](#see-all-bdd-targets)
    - [BDDfiles](#bddfiles)
    - [Enviroment](#enviroment)
    - [Removing illegal chars from bdd .md files](#removing-illegal-chars-from-bdd-md-files)
    - [Building and Running BDD's](#building-and-running-bdds)
  - [Cleaning](#cleaning)
    - [Terminal visualization](#terminal-visualization)
  - [Reporter tool: tagion-regression](#reporter-tool-tagion-regression)
    - [Starting](#starting)
    - [Stopping](#stopping)
  - [Creating a new BDD](#creating-a-new-bdd)

# BDD documentation
The following md file contains documentation on how to develop with bdds. For a general understanding of what BDD's are please see: [Continous_Delivery_What_is_BDD](https://www.youtube.com/watch?v=zYj70EsD7uI).

# List of BDDs
For a complete list of BDD's that have been created see: [BDDs](../../../../bdd/BDDS.md)

## Structure
`bdd/tagion/testbench`

Source folder for all targets. Folders inside testbench are made for "grouping" related features together. One folder might contain several features related to the testgroup. For an example if you look in the directory `wallet` you can see the following:
* `Wallet_generation.md` contains the feature with all the different scenarios that the developer has written in "natural bdd language". 
* `Wallet_generation.gen.md` is an auto-generated file that has prettyfied and formatted and added function module names and classes. 
* `Wallet_generation.d` is the skeleton file based on the `.md` file. This is the file the developer fills with their code. 
* `Wallet_generation.gen.d` is an file that is updated according to the .md file. This is smart if an scenario description changes, then the developer can use a diff to merge the changes. 

The smart thing about this structure is that it allows developers in both directions to make changes. If the `.d` feature file has a function that is not needed anyway. The developer can remove the function and merge the changes. It can also be made the other way around if the feature description is changed to ex. other requirements.

## Commands
### Help 
To get help use:

`make help-bdd`

### See all bdd-targets
To get a list of all created BDD's use the following command:

`make list-bdd `

### BDDfiles
`make bddfiles`

Generate all the bddfiles. If you for an example have created a `.md` file this will genrate the `.gen.md & .gen.d & .d` files associated. It also compiles the bddtool

### Enviroment
`make bddenv`

Generates a environment test script in build called `bddenv.sh`. This script can be used for manually running a single bdd with enviroment using ex. `./bddenv.sh <target>`.

### Removing illegal chars from bdd .md files
`make bddstrip`

Strips bad chars from BDD markdown files in case that an editor might have added none utf-8 characters. 


### Building and Running BDD's
To build AND run all created BDD's use the following command:

`make bddtest`

This will build and execute all BDD's including the BDD-tool. It will show on a single line how many passed failed and were started. If you want more information about your logs use [reporter-tool](#reporter-tool-tagion-regression) 
If you just want to build the bdd, use the following command.

`make bddinit`

To run your build BDD's again or if you used `bdd-init` use:

`make bddrun`

If you just want to run a single test use the following command. This command will not print out the bdd-report, but only run the scenario:

`make run-<target>`

If you also want to show the result instead of just running the test use:

`make test-<target>`

## Cleaning

`make clean-bddtest` 

Removes the bdd log files

`make clean-reports` 

Removes all the bdd reports

### Terminal visualization
Produce visualization of the BDD-reports inside terminal:

`make bddreport`

## Reporter tool: [tagion-regression](https://github.com/tagion/tagion-regression)
[tagion-regression](https://github.com/tagion/tagion-regression) is a tool for viewing BDD results in the browser. See the hyperlink for a in-depth description of how it works. It will be started as a screen with name "node" and run on port 3000.
### Starting
`make reporter-start`

Will start the reporter tool on localhost 3000 with screen.

`make bddtest`

Also starts the reporter tool but runs and builds the other parts. See [Running BDD's](#running-bdds)

### Stopping
`make reporter-stop`

Will stop the reporter and screen.

## Creating a new BDD
ALL COMMANDS NECCESARY




