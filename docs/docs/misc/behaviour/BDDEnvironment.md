# BDD Environment

The root directory of the BDD source should be placed in $BDD.
All the test logs should be placed in $TESTBENCH and the name of the should be name $TESTBENCH/`<iname of bdd>`.hibon.


Make target
* make help-bdd : Displays the BDD help text
* make bdd : Runs all the BDD's
* make bddreports : Execute the bdd target and produce the log file.

The bdd make files is called behaviour.mk and the configuration file is called config.behaviour.mk.


