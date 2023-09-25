# Changelog for week 38/39
**Replicator Service**
The replicator service is finished. This service is responsible for saving a chain of the added and removed archives in the DART. This is both used for replaying the DART in case the nodes cannot reach consensus, and for a backup of the database allowing the node to recover from fatal catastrophes.
**Recorder Chain**
The Recorder Chain has been updated to include new data such as the epoch number. This is the chain that is used in the Replicator Service. The recorderchain util has also been updated allowing you to replay a DART.
The data stored is the following.
Fingerprint - the fingerprint of the block.
Bullseye - the bullsye of what the database should look like when the following recorder is added.
Epoch number - the epoch number which is correlated with the bullseye. This is important for also making the hash of the block unique.
Previous Fingerprint - A hash pointer to the previous block's fingerprint.
Recorder - The entire recorder that was inserted in the modify command to the dart containing all Adds and Removes of archives.
**HiBON Service**
We have created the initial version of the HiBON SDK along with a nodejs server which you can go use now. This allows you to use the HiBON format in nodejs to convert from HiBONJSON to HiBON.
You can take a look at the public repo here: https://github.com/tagion/npm-hibonutil/

**dartCrud check archives**
We have implemented a new dartCRUD command that can be sent with HiRPC. This command works just like dartRead but instead of returning all the archives it returns a list of all the DARTIndexes that were not found in the database. This is very useful for ex. checking if the bills in the DART are still present seen from a wallet perspective. (
# Changelog for week 37/38

**Transcript Service**
The transcript service that is responsible for producing a Recorder for the DART ensuring correct inputs and outputs archives is finished but needs further testing when some of the other components come into play as well.

**Collector Service**
The collector service which is used for collecting inputs from the DART and ensuring that the data is valid is finished but like the Transcript service it still needs further testing when the components are glued entirely together. 

**Startup flow** 
We have created the startup flow for mode0. This flow has been greatly improved due to our new actors, which allows us to use supervisors for the different tasks. 

**Monitor**
The monitor has been integrated into the new epoch creator which allows us to see a visual live representation of the hashgraph while the network is running. This service has also been refactored to use our new actor structure.

**Hashgraph**
The hashgraph's ordering has been updated to use a new ordering mechanism that uses something we have decided to call pseudotime. We will be posting more about this in the upcoming future.


# Changelog for week 36/37

**Hashgraph**
Event round uses higher function in order to avoid underflow when comparing mother & father rounds.
Several outdated tests were removed.

**Safer actors**
Fixed an oversight where actor message delegates were not checked to be @safe.

**Inputvalidator**
Updated the tests for the inputvalidator. 
Previous tests were underspecified and we now try to cover all paths. By sending, valid hirpcs, invalid Documents and invalid hirpcs.
The version flag for the regular socket implementation has been removed and we now only use NNG sockets.

**Event subscription**
Implemented an internal mechanism for subscribing to events via a topic in the system. Which makes it easier to develop tests that require to know the falsy states of a service. In the future it will be used to decide which events get sent out through the shell.

**HiBON**
Updated the documentation for HiBONJSON and provide samples in hibonutil for easier compatibillity testing.
ISO time is now the accepted time format in HiBONJSON as opposed to SDT time

**CRYPTO**
Random generators are seeded with the hardware random functions provided by the OS.

**Epoch Creator**
The epoch creator is the service that drives the hashgraph. 
It's implemented using a shared address-book and tested in mode-0.
The address-book avoids burried state which was a source of several problems previosly when bootstrapping the network.

**DART Service**
The DART service has been implemented and CRUD operations tested. 
The service allows several services to access the DART.

**OLD TRANSACTION**
The code for the old transaction mechanism has been seperated and moved in to the prior services. This means that the code lives seperately and the OLD_TRANSACTION version flag has been removed.



# Changelog for week 34/35

**NNG**
We have implemented the worker pool capability for REQ-REP socket in NNG. A worker pool allows us to handle incoming requests concurrently and efficiently.

**Actor services**
We have created a way to make request reply style requests in our Actor Service. This provides a better way for ex. when a service needs to read data from the DART and make sure the data is sent back to the correct Tid. It also includes an unique ID, meaning you could wait for a certain request to happen.

**Gossipnet in mode0**
We have changed the gossipnet in mode0 to use our adressbook for finding valid channels to communicate over. This implementation is more robust than the earlier one which required a sequential startup.

**WASM testing**
We have implemented a BDD for the i32 files to BetterC. It is created in a way so that it supports all the other files which means further transpiling will become easier.

**HashGraph**
The HashGraph implementation is done. This means the Hashgraph testing, re-definitions, implementation, optimisation and refactoring of the main algorithms are completed. The optimisation potential in Hashgraph, Wavefront and ordering algorithms and implementations are endless, but we have a stable and performing asynchronous BFT mechanism. Soon we will optimize the ordering definitions (Though they are working now) and add mechanical functionality for swapping.



# Changelog for week 33/34

**NNG**
We've completed the implementation of asynchronous calls in NNG -Aio, which enhances our system's responsiveness with non-blocking IO capabilities. The integration of NNG into our services has begun, starting with the inputvalidator.

**Build flows**
Our Android build-flows have been refined to compile all components into a single binary, enabling uniform use of a mobile library across the team. This optimisation is achieved through a matrix-run process in GitHub Actions.

**WASM Transpiling**
We can now transpile Wast i32 files to BetterC and automatically convert test specifications into unit tests. This advancement enables comprehensive testing of transpiled BetterC files.

**Hashgraph**
We've improved epoch flexibility in the Hashgraph, aligning with last week's adjustments to "famous" and "witness" definitions. It leads to events ending in epochs earlier, allowing for faster consensus.



# Changelog for week 34/35

**NNG**
We have implemented the worker pool capability for REQ-REP socket in NNG. A worker pool allows us to handle incoming requests concurrently and efficiently.

**Actor services**
We have created a way to make request reply style requests in our Actor Service. This provides a better way for ex. when a service needs to read data from the DART and make sure the data is sent back to the correct Tid. It also includes an unique ID, meaning you could wait for a certain request to happen.

**Gossipnet in mode0**
We have changed the gossipnet in mode0 to use our adressbook for finding valid channels to communicate over. This implementation is more robust than the earlier one which required a sequential startup.

**WASM testing**
We have implemented a BDD for the i32 files to BetterC. It is created in a way so that it supports all the other files which means further transpiling will become easier.

**HashGraph**
The HashGraph implementation is done. This means the Hashgraph testing, re-definitions, implementation, optimisation and refactoring of the main algorithms are completed. The optimisation potential in Hashgraph, Wavefront and ordering algorithms and implementations are endless, but we have a stable and performing asynchronous BFT mechanism. Soon we will optimize the ordering definitions (Though they are working now) and add mechanical functionality for swapping.

---

# Change log from alpha-one

- Options for the different part of the network has been divider up and moved to the different modules in related to the module.

- JSONCommon which takes care of the options .json file. Has been moved to it own module.

- Side channel problem in KeyRecorer has been fix (Still missing  second review)

- Consensus order for HashGraph Event has been changed to fix ambiguous comparator. 

- All the Wallet functions has been moved into one module SecureWallet.

- Data type handle Currency types has been add prevent illegal currency operations. The implementation can be found in TagionCurrency module.

- Bugs. HiBON valid function has been corrected.

- Hashgraph stability has been improved specially concerning the scrapping on used event. 

- Node address-book has been moved into a one shared object instead of make immutable copies between the threads.

- Boot strapping of the network in mode 1 has been changed.

- DART Recorder has been improved to support better range support.

- HiBONRecord has been removed

- HiBON types has been change to enable support of other key types then number and strings. (Support for other key types has not been implemented yet).

- Support for '#' keys in DART has been implemented, which enables support for NameRecords and other hash-key records.

- The statistician is now a HiBONRecord.

- Old funnel scripting has been removed opening up of TVM support.

- Asymmetric encryption module has been add base on secp256k1 DH.

- HiRPC has been improved to make it easier to create a sender and receiver.

- The build flow has been improved to enable easier build and test.

- The tools dartutil, hibonutil, tagionboot, tagionwave and tagionwallet has been re-factored to make it more readable.
