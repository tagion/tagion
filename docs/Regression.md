## Regression plan

* Environment setup for the BDD logfiles
* Make target to generated the .d and .md files from the BDD's
* Make target for  compilation/link of BDD.
* Make target execute all the BDD as binaries
* Aggregate all the bdd logfile and generate a visual representation (HTML or markdown)
	* Same for unittest.

* Enable code coverage for which should be enabled for all binary execution and aggregate
	* and add a visual log for the "cov"
* Make target which do DDOC (via doxygen or adrdox)
* Make target which can merge a branch with a specific TAG to the "pilot" branch if all tests has passed
* Implementing continues code-review tool (using the criticize tool)
* Make target for the cogito-tool and aggregate an visual report.
* Make target which should pre-install the dstep,dfmt,cogito,dmd,ldc2 ... using dub

