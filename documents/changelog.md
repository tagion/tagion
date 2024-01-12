# Changelog for epoch 131000 .. 392368

Happy new year! :tada:
Here is the first changelog of the year.

**DART**
Now that we have actual real life data to test and measure performance with.
it makes it much easier to see where bottlenecks occur.
One improvement has already been made when calculating the merkle root of very large dart database.
Which should make it significantly faster.
The improvement is made when a rim is filled out, we then take the raw hash of the entire instead of summing up the hashes of all the branches.
We've already noticed a few other bottlenecks and improvements are on their way!

**TRT**
The TRT has been enabled in all acceptance stage tests and is currently running in the operational tests.

**Shell**
If an error occurs in the shell it is now reported in the response.

**Wallet fix**
Fixed a bug in the wallet where it would not be able to handle multiple locked/requested bills with the same public key.

**HiBON dub Package**
HiBON is now available as a library in the D package registry.
You can use it in your dub project with

```bash
dub add tagion:hibon@~master
```

Note that hibon subpackage is currently only available in the master branch.
Later you should prefer the to use the latest release. (eg. @v1.1.0)


**Docs**
Improved and added documentaton for several services and api's. 
Including the TRT, Subscription, Auszahlung, cli & options for neuewelle, architecture overview.
The documentaton is as always available on docs.tagion.org. Previously some pages were missing from the online deployment, this should be fixed now.

The hibon specifications has now been completely removed from the core repo and is now only available on https://www.hibon.org


# Changelog for epoch 50000 to 131000
**Wallet update on existing response**
The wallet can now take an existing HiRPC.Result and modify itself based on that. This allows you to send your requests with curl and later modify your wallet with the responses.

**TRT Improvements**
We now have a working prototype on our TRT, which will allow much faster and efficient lookups based on public keys. We are now beginning the testing phase for this feature.

**NNG Tagionshell memory leak**
We have had a small memory leak in the shell due NNG spawning pthreads from c, which were not properly attached. This was resolved by calling: `thread_attachThis` in the threads.

**BlockFile and DART readonly mode**
When opening the DART in RO-mode we do not load the recycler which allows for faster loadtime.

**Synchronized LRUT**
We have created the initial synchronized LRUT class (Least-recently-used-threaded) which will be used in the shell for caching.

**Neuewelle refactor**
The main binary for spawning a node / network has been refactored so that it is much easier to understand now.

# Changelog for epoch 0 to 50000

**getFee(amount, fee) patch**
There was a bug in the getFee function from amount because the bill used for getting the size was using null values for the pubkey, nonce etc. This has been fixed by setting the sizes statically ensuring the fee is calculated to be the same as the `createPayment` function.

**LRU support for none atomic key-value**
Our least recently used class has been upgraded so that it is possible to use none-atomic key-values.

**Versioning**
We have updated our revision to include the latest tag. The revision for example looks like the following now.

version: v1.0.1+dev+dirty
git: git@github.com:tagion/tagion.git
branch: current
hash: 6258adbd9a805a16edb0f748553de00f69bcb76f
revno: 12834
build_date: imrying
builder_name: philiprying@gmail.com
builder_email: gcc (GCC) 12.3.0
CC: DMD64 D Compiler v2.105.2

As it can be seen it shows that the binary is on top of v1.0.1 with develop and the working tree is dirty when it was compiled.

**.isMethod patch**
We had a problem if you send a hirpc response as a input the service would throw an error. This has been mitigated so that it does not fail now.

**HashGraph startup problem**
We have had a problem with the hashgraph, where it sometimes would not produce any epochs and create an assert on a wavefront. This was because some empty events where not filtered out. This has been fixed so that the startup is completely stable now allowing our pipeline to be more trustworthy.

**Open sourcing**
Regarding open-sourcing the licenses have been updated as well as the CONTRIBUTING.md file.
The github action for creating the ddoc documentaton has also been fixed so that it now runs.

# Changelog for week 48/49

**Graceful shutdown**
We have implemented a mechanism for nodes to execute a graceful shutdown, ensuring that their states are saved before the shutdown process. This feature is particularly valuable during software upgrades.
**ReceiveBuffer bug**
We had a bug in our implementation of our non-blocking socket against the shell. This has been fixed. This issue was found by sending very large transactions with over 100 outputs through.

**Fee change**
The fee is now not dependent on the number of bills but rather the amount of bytes they fill. The simple calculation for a transaction is therefore the following.
(output_bytes - input_bytes)*FEE_PER_BYTE + BASE_FEE. The quick one will spot that it is possible to produce a transaction with multiple inputs to one output resulting in a negative fee. This is on purpose in order to incentivize clients to decrease the amount of information that there is located in the database. A simple way to think about it is that it is like a deposit to the network, and the money will be returned to you if you decide to decrease your number of bytes in the database.

**The classic bug: while(true)**
Our DARTInterface that sends forwards requests from the shell had a while(true) loop without a sleep. This caused the system to utilize 5cpu cores to the max. This has been fixed meaning that a node uses around 500% less cpu.

**General Update from Core**
We are getting extremely close to going live now and we are looking so much forward to you who have been following these changelogs to be able to use and see what we have created and talked so much about.


# Changelog for week 47/48

**Transcript bug**
Our operational tests found a bug where because the order of operations when iterating a hash-map is not guranteed we could end up in a scenario where the nodes would have the same state, but write different archives in different epochs regarding the consensus voting. This has now been fixed.

**Crypto tape-out**
We have had a final review of our secure-modules and they are now in the process of being externally reviewed one more time before go-live.

**Wallet bug**
We have fixed a bug in the wallet where the fee would be calculated incorrectly. This was due to a bug in the `createPayment` function that gathers the bills which are neccesary for creating the transaction.

**NNG memory leak**
We encountered a problem with the NNG-http server where it would leak memory when passing a `char*` to a c-function. This only happens when the string is concatenated with another string, which is a lazy operation. When then taking the pointer of this new variable it only points to the "first" part of the string meaning the other part leaks in memory. This problem has now been mitigated by manually allocating the memory using a static buffer which makes sure it is properly cleaned afterwards and creates a fully monolithic pointer.


# Changelog for week 46/47

**Boot from passkeys**
The wave program can now boot from passkeys meaning from stdin, meaning that you can use ex. a GPG key to manage the passwords for the network or a usb.

**Epoch chain**
The Epoch chain implementation is finished, meaning that on each epoch, the epoch including global parameters is written. We have also changed the way that this happens, so that we actually write epochs from the hashgraph immediatly and everytime we add a new vote instead of only writing it once. It is completely finished and includes majority votes. This makes the system more resilient, since if it goes down the votes are stored in the database rather than in memory.

**Crypto**
We do no longer scramble the privatekey, but instead set all bits to 0. This provides the same security while being much faster since we do not have to create a system call to `getrandom(2)` each time.

**ActorHandles**
The ActorHandle implementation has been changed so that it is no longer templated, and instead of doing a `locate`, it tries to send immediatly to the previous `tid`. If the `tid` does not exist we set the `tid` and try again. This implementation is faster and safer, since we do not have to do a locate each time and handler errors.

**NNG nothrow**
Most of NNG is now marked nothrow, which allows functions above to also inherit the nothrow attribute making error handling more clear.

**Operational test**
A operational test has been created which is essentially a wrapper around a bdd-test which sends a tx from walletA to walletB. This randomly selects two wallets and continiously creates a transaction between these for a specified amount of time.

**General Update from the Core**
We are very happy to announce that all ground components for the network are finished. This means we are going into Tape-Out mode now and will be doing final reviews on everything and have full focus on operational testing of the system.


# Changelog for week 45/46

**Blockfile**
Fixed an error in the blockfile where the cache would be allocated preruntime,
meaning that multiple blockfiles would use the same cache, even running in seperate threads;
This was a cause of multiple derived errors, which has now been fixed.

**Crypto**
Default signatures are now Schnorr.
Add xonly public key conversion functions.

**NNG**
fix NNGMessage allocation
add tests with larger messsages(1-2MB)

**Shell**
Initial documentation for the shell caching layer has been added.

**AssertError**
There is now a top level catch in each actor thread, which catches AssertErrors and stops the program.
Previously AssertErrors would stop the thread and reach the main thread wihout being reported or stopping the program.

**Wave**
Add `--option` flag to be able to set individual options.
Can be used with -O to change the options file permanently

**HiRPC error type**
The HiRPC error type has been changes so it's always considered an error, if it's not a method or a result.

**CI**
The CI workflow can now run on any branch.
Testnet worflow cleans old backups & main worflows cleans old artifacts

# Changelog for week 44/45

**Tagion HEAD record**
The tagion HEAD name record stores all the global statistics about the current network in the DART.
Like the epochnumber, total money supply, number of bills, etc..

**Genesis Epoch added**
The Genesis Epoch is the network boot record.
Where we the system stores all the information required to bootstrap the network.

**Hashgraph epoch number**
In order to stay clear of future overflows,
the hashgraph epochnumber and the transcript service has been switchted from an int (32-bit) to a long (64-bit).

**Epoch Votes**
The epoch is now created based on the votes of the DART bullseye.

**Crypto**
Schnorr signing and verification functions added.
The NativeSecp256k1 module now features MuSig2 functions for multi signatures utilizing those Schnorr algorithms.

**Fixes & Stabillity improvements**
 * We have made changes to how the node starts the replicator service. 
 * Improved the way the transcript stores and cleans votes.
 * Removed some unsafe type casts.
 * Fixed error with unflushed DART writes.
 * Created improvements to the Error replys when sending a contract and making a DART read request.
 * Fixed the inputvalidator test, which used the wrong socket type.
 * ...

**Remove legacy code**
We have removed all of the SSL modules.

**CI Improvements**
The CI flow now runs in several steps, so we have better error reporting when and which stage fails.
The worflows times out when a job hangs. And it always produces an artifact so we can inspect the errors.


# Changelog for week 43/44
**Malformed Contract scenarios**
We have implemented various scenarios where the user tries to send an invalid contract. This could be where some fields of the contract are missing. Or when it comes to transactions, the user could send an input that is not a bill, among many others.

**Faucet shell integration**
We have integrated a faucet functionality into the test version of the shell, allowing us to easier test the wallets since they now can request test-tagions.

**Secp256k1 multisig and change of library**
We have updated our library from the secp256k1 library located in bitcoin core to https://github.com/BlockstreamResearch/secp256k1-zkp. The reason why we have made this change, is because we want to support multisig for various parts, and this is a functionality that is good to get into the system before it is running in its final state because it is very difficult to update. We have therefore started to implement schnorr signatures for signing.


# Changelog for week 42/43
**Shell Client**
We have commited a WebClient with TLS support. See [github.com/tagion/nng](http://github.com/tagion/nng) test example test_11_webclient.d. This makes for a very small and easy to use webclient for our CLI wallet among other places. Currently only synchronous GET and POST methods are available.

**HiBONRecord @labels**
We have refactored the way HiBONRecord labels are defined so that it is easier to understand. See the following example:

Now we can do the following:
```struct Test {
  @exclude int x;
  @optional Document d;

  mixin HiBONRecord;
}```

Instead of:
```struct Test {
  @label("") int x;
  @label(VOID, true) Document d;

  mixin HiBONRecord;
}```
**SecureNet Services bug**
We ran into a problem where our securenet would sometimes return that the signature was not valid event though it was. This only happened when running multithreaded and doing it a lot concurrently. The problem was that due to secp256k1 not being thread safe, we were using the same context for all the threads, which of course is not good. Therefore we now pass a shared net down to all services, where each creates its own context. Also services that do not perform any signing by themselves, but purely check signatures like the HiRPC-verifier now create their own SecureNet.

**Consensus Voting**
We have implemented the functionality for sending the signed bullseye around after a DARTModify. The reason for doing this is in order to check that all nodes have the same excact state. If more than 1/3 of the nodes do not agree then they will perform a roll-back of the epoch.


# Changelog for week 41/42
**Shell with HTTP proxy**
The shell has been updated to use our NNG http proxy now so that it is possible to send a transaction through with http. 

**Double spend scenarios**
We are working on different testing scenarios currently, and the last week was spent doing testing around double spending which went very well :-). 

**Subscription Service**
We have implemented a subscription service that wraps our internal subscription and allows external clients to subscribe to different events with NNG. This could for an example be every time we create a modify transaction to the DART.

**Tooling on genesis block**
We have created and updated tools to support functionality for the genesis block. This includes asking the database to retrieve all bills with regex searching among many other things.

**Epoch creator**
The epoch creator has been updated to use true randomness making the communication with other nodes more unpredictable. This is important for security of the nodes, because it helps prevents malicious actors in contructing for an example coin-round scenarios.

**LEB128 check for invariant numbers**
We only support the shortest form to write numbers with LEB128 in order to make HiBON truly hash invariant. In order to achieve this we have to make sure that the LEB128 number is always represented in the shortest way possible. The number 0x80 and 0x00 are ex. both equal to 0x00.


# Changelog for week 40/41
**NNG http proxy**
We have created a wrapper on NNG allowing us to create http-endpoint wrappers which can use underlying nng sockets. This is very smart, and you can now start a webserver by doing the following.
```
    WebApp app = WebApp("ContractProxy", options.contract_endpoint, parseJSON("{}"), &options);
    app.route("/api/v1/contract", &contract_handler, ["POST"]);
    app.start();
```
The structure is heavily inspired by FLASK python. All the code for creating the webapp can be found in https://github.com/tagion/libnng repo. 

**Archive Hash key**
Since the DART is a sparsed merkle tree, there can be some scenarios where it is quite difficult to use raw. For an example if I want to create a DNS-like structure containing a domain name and a IP the hash of the archive will change every time I update the IP, making it difficult to use. Therefore we have implemented Archive Hash keys which allows us to create a relationship between two datapoints. This means that our epoch-chain will also be much simpler, since you will be able to lookup epoch 4234 directly without running through a chain.
It works by using an archive member named "#<name>" as the dartindex instead of the hash of the archive.

**Collector Service**
The collector has been updated so that the list it receives of archives is ordered. This makes the logic for the collector much simpler, since it does not have to do unneccesary sorting work.

**Build flow updates**
We are always striving for better workflows in order to minimize time spent compiling etc. This week we have optimized our make flow even more which have drastically reduced our build times.

**HiBON npm package**
We have finished our NPM package, which is now also open-sourced and can be found here: https://www.npmjs.com/package/hibonutil-wrapper.
This allows you to interact with HiBON in node-js. An example of a use case is parsing HiBONJSON into a HiBON structure.
```
  const hibon = new HiBON(JSON.stringify(req.body));
```
We are very excited about this because it will make it easier to use HiBON for all other developers.  

# Changelog for week 39/40
**Merging new services**
The following week was spent gluing the last parts of our new service infrastructure together and further testing of the different components. We can now say that all our different services are communicating with each other and running. This means that refactoring of the service layer is mostly finished now and we are even able to send tagions through the new system.

**DARTInterface service**
We have created a new service for the shell to communicate effiecently with the dart. This is done via a NNGPool that has a fixed number of slots and allows multiple clients to open a REQ/REP socket. The NNGPool then manages when the sockets can bind and get an answer from the dart.
This in return means that the updates for the wallets will be much quicker as they do not have to go through the entire contract execution pipeline.

**TVM service**
We have created a new service for the TVM ("Tagion Virtual Machine"). The service is responsible for executing the instructions in the contract ensuring the contracts are compliant with Consensus Rules.

**BIP39**
We have updated our implementation of BIP39 mnemonic seed phrases to use pkbdf2 as the standard suggests. This is important because it gurantees that if you use the same keys on other wallets you will generate the same seed phrase. 
We did though find the standard implementation of BIP39 to be a bit weird in the sense that it does not use the index of the words in the words list for creating the hash but rather all the words?!. Using the words provides no benefits other than making the implementation more language indenpendent.
Though instead of diverging from the standard we have now implemented it according to the standard as well.

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
We have implemented a new dartCRUD command that can be sent with HiRPC. This command works just like dartRead but instead of returning all the archives it returns a list of all the DARTIndexes that were not found in the database. This is very useful for ex. checking if the bills in the DART are still present seen from a wallet perspective. 

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
