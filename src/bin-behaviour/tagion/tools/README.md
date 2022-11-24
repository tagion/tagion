- [BDD documentation](#bdd-documentation)
  - [Structure](#structure)
  - [Commands](#commands)
    - [Help](#help)
    - [See all bdd-targets](#see-all-bdd-targets)
    - [Running BDD's](#running-bdds)
    - [Building BDD's](#building-bdds)
  - [Creating a new BDD](#creating-a-new-bdd)

# BDD documentation
The following md file contains documentation on how to develop with bdds. For a general understanding of what BDD's are please see: [Continous_Delivery_What_is_BDD](https://www.youtube.com/watch?v=zYj70EsD7uI).
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

### Running BDD's
To build AND run all created BDD's use the following command:

`make bddtest`

This will build and run all BDD's including the BDD-tool. If you just want to build the bdd, use the following command.

`make bddinit`

To run your build BDD's use:

`make bddrun`
If you just want to run a single test use the following command:

`make run-<target>`

### Building BDD's
If you are not interested in running the BDD, but instead just want to compile it use the following command:

`make `


## Creating a new BDD





