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

Generate all the bddfiles. If you for an example have created a `.md` file this will genrate the `.gen.md & .d` files associated. It also compiles the bddtool

### Enviroment
`make bddenv`

Generates a environment test script in build called `bddenv.sh`. This script can be used for manually running a single bdd with environment using ex. `./bddenv.sh <target>`. Remember you can configure the script to run with a different stage like: 
`make bddenv TEST_STAGE=commit`.

### Removing illegal chars from bdd .md files
`make bddstrip`

Strips bad chars from BDD markdown files in case that an editor might have added none utf-8 characters. 


### Building and Running BDD's
To build AND run all created BDD's use the following command:

`make bddtest`

This will build and execute all BDD's including the BDD-tool. It will show on a single line how many passed failed and were started. If you want more information about your logs use [reporter-tool](#reporter-tool-tagion-regression) 
If you just want to build the bdd, use the following command.

`make bddinit`

To run your build BDD's again or if you used `bddinit` use:

`make bddrun`

If you just want to run a single test use the following command. This command will not print out the bddreport, but only run the scenario:

`make run-<target>`

If you also want to show the result instead of just running the test use:

`make test-<target>`

### Cleaning

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

### Stopping
`make reporter-stop`

Will stop the reporter and screen.

## Creating a new BDD
The following describes how to create a new BDD.
### Create a .md file for the feature
*Start by creating* a `.md` file in `bdd/tagion/testbench/<folder>`. Here you describe your scenarios. For examples check out [BDDs](../../../../bdd/BDDS.md). The text you write can just be "unformatted" text since the tool willl automatically add formatting. 

### Main file for the feature

Next you can "translate" your `.md` file by typing:

`make bddfiles`

This will generate a `.gen.md`, and `.d` file. 

Create a "main" file and import this file in `testbench.d` and give it an alias ex. like the file `bdd_wallets.d`. You can use on of the other files as an example. Inside the main file remember to import your package inside your folder. 

Now you can run make `bddtest` to run your created BDD. 

## BDD re-usage
It is possible to get an object after running a feature. This object can be imported into another feature. Thereby the BDD's can be linked on code that has been "verified" works. 
### Re-using
In your main file give the previous feature object as a input to an constructor:

```
int _main(string[] args) {

    const string module_path = env.bdd_log.buildPath(__MODULE__);
    const string dartfilename = buildPath(module_path, "dart_mapping_two_archives".setExtension(FileExtension.dart));
    const SecureNet net = new DARTFakeNet("very_secret");
    const hirpc = HiRPC(net);

    DartInfo dart_info = DartInfo(dartfilename, module_path, net, hirpc);

    auto dart_mapping_two_archives_feature = automation!(dart_mapping_two_archives)();

    dart_mapping_two_archives_feature.AddOneArchive(dart_info);
    dart_mapping_two_archives_feature.AddAnotherArchive(dart_info);
    dart_mapping_two_archives_feature.RemoveArchive(dart_info);
    
    auto dart_mapping_two_archives_context = dart_mapping_two_archives_feature.run();
    return 0;
}

```



