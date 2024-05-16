# Changelog for Epoch 1689534 .. 1861240
** HiBON/Document API **
The HiBON and Document API are mostly done and created as classes in javascript which uses the WASM file populated with the functions from the C interface.
We are also currently exploring using it for our mobile platforms via Flutter.

** Mirror node proposal **
We've created a proposal for mirror nodes, that will act as relay stations for serving information to clients. They are essentially the exact same node, but without running consensus.

** New witness definition **
We are still working on the hashgraph and have moved a long way with creating a new algorithm for very fast finding witnesses. 

** Envelope documentation **
We have documented the protocol for using the envelope for compressing information in the system.


# Changelog for Epoch 1569150 .. 1689534

** Tool Testing **
Implemented multiple CLI tool tests for dartutil, hirep, and hibonutil.

** HiBON API **
Introduced a C-API for HiBON, enabling the addition of keyalue pairs to HiBON objects through a `void*` parameter as an extension to what was done last week on the Document API. Documentation for both the HiBON API and Document API can be accessed [here](https://ddoc.tagion.org/tagion.api.html).

** NNG CI Workflows **
Established CI workflows for the NNG library, automating build processes and test executions directly on the library functions.

** Service Refactoring **
Removed the `waitForChildren` step in the tagionwave program. Tasks can now send messages without waiting for thread startup completion. This eliminates the "starting" state, simplifying network stopping logic previously affected during the "starting phase."


# Changelog for Epoch 1287717 .. 1569150

** Envelope tool **
We have created a new CLI tool for packaging hibons into an envelope.  

** Tagionshell envelope **
The shell now accepts envelope packages along normal raw documents.  

** Document API **
Initial work on the document API has started and most basic functions are supported for getting the native hibon types out. This is one of the interfaces that will be used for WASM.

** Tool tests **
We have started to implement CLI tool testing in BDD, in order to test that all user-facing switches work as intended

** Fix names of internal records **
Fixed the name of ConsensusVoting record used in gossip, where it would not used the reserved name.
Unified name of Signature members, so they always use the same "\$sign" name

** Fixed Crash on some chipsets **
Our new faster hibon serialization function caused a crash on some chipsets. Specifically the "Snapdragon 8 gen 1" and a few others.
We've reverted back to the old serialization functions on the affected platforms.

** Node Interface **
Initial work for the mode1 "node interface" service is done.
The service' purpose is to facilitate efficient p2p communication for the distributed mode1 network.
It's implemented using nng's aio & stream functions.
Right now the basic asynchronous managing of connections and messages have been implemented.
Next steps are to keeping the state of the connections according to our wavefront protocol. Including dealing with "breaking waves".
And ofcourse this will also involve writing plenty of tests.


# Changelog for Epoch 1287717 .. 1397424

** Make-flow improvements **
We have updated the makeflow to use `dmd -I` instead of specifying all the files. This has turned out to be must faster to compile which has lead to a 50% decrease in our compilation times. 

** Collider network namespaces **
The collider tool is now able to use `bubblewrap` in order to spawn the different processes in their own namespace. This means that multiple of the same tests with the same sockets can be executed on the same machine parallelly. This is basically the same thing that Docker and similar container tools do, but the smart thing is that we do not have to for an example create a virtual filesystem as well. 

** Websocket hashgraph monitor **
We have finished an initial prototype of a new hashgraph web monitor which works with the NNG websocket server functionality that was made last week. 

** Contract storage / tracing in TRT tests **
The contract storage tracing has now been tested with both contracts that should and should not go through. 

** Automatic Mode1 bddtest on acceptance stage **
The mode1 test has been improved and is now executed automatically on acceptance stage. It also checks if all the nodes are producing epochs by subscribing to them.

** Hashgraph consensus debugging **
We are still working on fixing the consensus bug in the hashgraph. We have implemented a test which runs in a fiber instead of separate threads. By defining weighted randomness on how often the nodes are selected for communication and using deterministic randomness we have managed to create a test which fails consistently. This makes debugging the problem a lot easier since we are now actually able to see if it fails or not. The `graphview` tool has also been updated so that it now can generate side-by-side graphs for all the nodes, allowing them to be easily compared.


# Changelog for Epoch 1189390 .. 1287717

** HiREP updates **
The HiREP tool has been updated so that it can filter on sub-hibons. This is very smart for ex filtering out specific elements from ex. the TRT.

A new feature was also added to the `-l` flag which means you can specify `-1` as an index which will give you the last index in the range.

** Mode1 BDD test **
We have created a testbench bdd which can run nodes in different processes. This means that we now can spawn a mode1 network using a testing tool allowing us to implement various other tests on the mode1 network.

** Graphview **
We have a bug in our hashgraph which occurs very rarely. This means that the graphs we have to debug are extremely large and using [GraphViz](https://graphviz.org/) for generating the graphs have become a real problem since it crashes with more than ~10000 events. Therefore we have implemented a way to generate the svg directly without graphviz which is much simpler and faster. Our CI has also been updated so that it now generates the graphs automatically if there was an error. If you did not think the core-team could do styling think again! :-D.

** TRT Contract storing **
We have implemented a new archive in the TRT, which stores successfully executed contracts along with the epoch number. This allows clients to perform a `trt.dartRead` with the dartindex being the contracts hash and getting back which epoch it went through. Common for the TRT is that it is not the database but merely a lookup table for clients to more easily use the system.

** HiBON Backward compatibility test **
We have added a test which produces a HiBON containing all fields. This HiBON is then committed in git and checked in the unittest each time they are executed that the current binaries produce the same output.

** Envelope fixes **
We have refactored the Envelope so that it is little endian by default among other things.

** True websocket server **
We have created a websocket server that works in the same way as normal websockets such as python standard websockets etc in the NNG library. This will allow us to easily show our graph and be more compatible with other languages standard websocket implementations. 


# Changelog for Epoch 1104102 .. 1189390

**Epoch operational test**
We have created a test that runs many epochs very fast, which is able to give us insights into problems with the Hashgraph. It subscribes and checks raw epochs before they enter Refinement. 

** WASM get_random and signatures in the browser **
We managed to get the `get_random` function to work in WASM in the browser. This is difficult since the normal system functions are not available, and therefore we have to call a browser function in order to retrieve random data from WASM. This is now working, which has allowed us to create Signatures in the browser with WASM. A huge milestone in the process of creating Tauon.
**Recursive search for HiREP**
We have implemented recursive search for the tool hirep. This allows for a more broad range of use-cases, since it can eg. be used to retrieve all pubkeys in a database.

```bash
  dartutil dart.drt --dump |hirep -n \$Y --rec|hibonutil -pc
```

**Graph View**
Fixed a bug where the graphview tool used int instead of long for the epoch height.

**NNG websocket**
We have created a high level wrapper around STREAM, which allows for easier websocket handling like in other languages with `on_connect`, `on_message` etc.

# Changelog for Epoch 1048744 .. 1104102

**NNG Stream**
We have wrapped the nng stream api, to use with connections which are not compatible with the nng protocols.
This could be a simple tcp or websocket connection. To be used for the explorer and possibly p2p communication.

**Subscription API** 
A proposal was made for the interface to the external subscription API [TIP 3](http://docs.tagion.org/tips/3).
This proposals goal is to enable an api for realtime wallet and explorer updates.

**Shell HiRPC handler**
The endpoints for sending hirpcs to the shell has been compressed to a single endpoint `/api/v1/hirpc`.
This should be simpler to use and fits better with the rpc pattern.

**Contract tracing**
We have added the the initial events for the contract states.
And added `--contract` flag to the subscribe tool, this flag takes to the base64url hash of a contract as a parameter.
The tool will then continuously give you updates about the contracts state.
This flag is quite specific and we are still dissussing how it should be used.
It's possible that the flag will be removed again in favour of something more general purpose.

**Graphview**
Graphview is our development tool to render a graph from the graph data.
The data format which is uses is now streamable and compatible with the internal event monitor.
The event monitor, if enabled sends out all the evenview data.

**Nix**
Several pre-commit checks have been added to flakes development shell.
These include linting for github actions, shell & spell checking.
This should help prevent all of the small spelling mistakes that appear from time to time.

A nixosModule for the tagionshell & tagionwave services were added.
So you enable them directly from your nixosConfiguration by providing "github:tagion/tagion" as an input.

# Changelog for Epoch 793069 .. 1048744

**New Documentation page**
We have created a new documentation webpage that is built using [docusaurus](https://docusaurus.io/). See [https://docs.tagion.org](https://docs.tagion.org) for more info. The DDOC documentation has also been moved to a subpage on `/ddoc/tagion`. This also allows the search-box to support searching across all documentation. Currently there is a problem with the statically generated sites for ddoc in the search box, which requires the client to refresh the page when entering a ddoc page (thanks react :-) ).

**Subscription tool**
Initial work on the [subscription tool](https://docs.tagion.org/docs/tools/subscriber) has begun, and the tool now works where you are able to subscribe to various tags.

**Async startup of nodes**
For years we have had problems with booting the hashgraph in a asynchronous way regarding the boot of the hashgraph. This is due to that you somehow have to start a graph by only knowing the other nodes addresses which is rather difficult. This has now been fixed so that each node may be booted with n delay in between. This change also allowed us to remove the Locator.d which was necessary before.

**Mode1 network boot!**
The initial mode1 network boot succeeded this week. Lots of work have been going into cleaning up the interfaces and making the new `NNGGossipnet`, and together with the above change regarding async booting the mode1, network can now successfully start and produce epochs.
You are even able to shutdown various nodes and the graph will continue running and produce epochs as long as 2/3 of the nodes are still online.

See more information about different modes [here](/docs/architecture/network_modes).

**TVM standard library (Tauon)**
We have begun work on the standard library for Tauon ( *named after the elementary particle [tau/tauon](https://en.wikipedia.org/wiki/Tau_(particle))*). The thing that makes the Tauon difficult to do is that is has to be executable from WASM which means most of DRuntime is not supported. We are therefore working on adding / removing features from druntime until that we are able to compile all functionality that we would like. Currently we are as an example able to run the following example in WASM/WASI:

```dlang
module tests.tauon_test;

import tvm.wasi_main;
import core.stdc.stdio;
import std.stdio;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.basic.Types;

void main() {
    printf("--- Main\n");
    int[] a;
    a~=10;
    printf("a=%d\n", a[0]);

    writefln("a=%s", a);
    auto h=new HiBON;
    h["hugo"]=42;
    writefln("h=%s", h["hugo"].get!int);
    writefln("h=%s", h.serialize);
    writefln("h=%s", h.toPretty);
    writefln("h=%(%02x%)", h.serialize);
    writefln("h=%s", h.serialize.encodeBase64);
}

```

# Changelog for Epoch 720414 .. 793069

**Tagionshell automatic test**
We have implemented a automatic test on the shell for the acceptance stage. Until now we have only had automatic tests on the shell when running the longitudinal tests, so this makes it easier for us to catch errors quicker. The test also utilizes our new trt-read update process.

**Contract Tracing proposal**
We have created a proposal for how the tracing of contracts should be implemented. See [docs.tagion.org](https://docs.tagion.org/#/documents/TIPs/contract_tracing_proposal_18_feb) for further information.

**HiBONJSON timestamp formatting**
We use a function from D's standard library for converting from hibon's time format sdt time which is represented as a 64-bit integer and the ISO8601 text format. Which looks like this `2024-02-12T11:15:37+07:00`.
The problem is that the timezone can be omitted like this `2024-02-12T11:15:37` and the timezone would then be assumeed to be the local time.
This is the default behavior for the library function which means that the timezone would never be included in HIBONJSON. 
Which meant that a hibon including a timestamp. When converted to json and sent to another timezone and converted back to hibon
would no longer be the same timestamp and of course no longer the same hash.
We have made a temporary solution for this, but it seems to cause issues on some platforms see https://github.com/tagion/tagion/issues/406

In the process we also found a bug in the function that converts from the text format to the binary format 'fromISOExtString()`.
Which would not correctly subtract the time offset in non hourly timezones like Indias `IST(UTC +5:30)` or Canadas NST(UTC -2:30).
Which we did not even know existed.
This means for now that the standard hibonjson implementation does not allow converting from a string timestamp with an un hourly timeoffset.


# Changelog for Epoch 548959 .. 720414

**HiBON bug fixes and enhancements**
We have resolved an issue in HiBON where sub-document length fields were incorrectly calculated. The fix not only addresses this bug but also optimizes HiBON for increased speed. The update enables more compile-time introspection, facilitating the creation of custom compile-time serialization functions and sorting when using HiBONRecords. Specifically, when a mixin HiBONRecord struct contains only simple types, the calculation of `full_size` and the `serialize` function occurs during compile-time. If the HiBONRecord includes non-simple types, the generated serialization function estimates the size of the final struct, minimizing new allocations during serialization/deserialization. Additionally, HiBON now utilizes Appender[] for appending elements, recommended over `array ~= data` when dealing with multiple appends.

**`verify` function bug**
Addressed a bug in the `verify` function where supplying 0 inputs would incorrectly return true. This bug has been fixed to ensure accurate behavior. Although other checks in the contract would still catch issues, correcting this bug improves the efficiency of the Node by reducing unnecessary computations.

**CI-Flow Improvements**
We have streamlined the CI-flow by reorganizing and grouping related elements. Previously, service files for tagionwave and tagionshell were located in separate "bin-x" directories, but now they are consolidated into a common "etc/" folder. Additionally, frequently used scripts for starting the network have been grouped into a dedicated "scripts/" folder. This reorganization simplifies CI-flows, eliminating the need to modify the make-flow for the correct inclusion of files in the artifacts.

**HiBON Envelope Protocol**
Introduced the first iteration of the HiBON envelope protocol, enhancing HiBON's capabilities. This protocol allows HiBONs to be sent with compression and a CRC checksum, resulting in significantly reduced package sizes for communication between nodes and from client to shell. Currently, only zlib compression is supported, but future updates will introduce additional compression types. Future iterations may also include headers for implementing encryption.


# Changelog for epoch 548959 .. 624229

**Improved Documentation**
We have started initial work on improving our documentation. This includes a new page listing all interfaces for a node along with what methods are supported for each interface. You can check out more here on [docs.tagion.org](https://docs.tagion.org/#/documents/protocols/contract/hirpcmethods).

**nix build .#dockerImage**
We have created an output in our `flake.nix` file that allows for a minimal docker image to be built on alpine linux. It does not start any services but allows for easy usage on non-x86_64-linux systems to use eg. `hibonutil`. We suggest taking a look since it is a nice showcase of the cool possibilities with nix :-).

**DocumentWrapper bugfixes**
We have fixed some errors in the `DocumentWrapperAPI` regarding return types. For an example the function `doc_get_ulong_by_key` previously returned a `int64_t` but was supposed to return `uint64_t`.

**HiRPC subdomains**
We have implemented what we call *HiRPC subdomains* which allows for forwarding requests to different parts of the system. If you want to do a `dartRead`, but instead of performing it on the main DART, you want to perform it on the `TRT`, you can perform a request with method name `trt.dartRead`. Internally in the different actors they don't care, and only use the last name for figuring out which requests to do, but in the `DARTInterface`, the request can be either send to the TRT or DART.

**TRT lookup request**
We have implemented a new way for wallet update, which is a lot more efficient and should put less load on the system than the previous "search". It works in two steps.
First the wallet collects a list of all its deriven public keys. It then performs a `trt.dartRead` to read all dart indices located on these public keys. 
By getting this information we can see if 1. we have received new indices (bills) and 2. if some of our bills are no longer located in the DART.
The wallet can then take the new indices and perform a `dartRead` on the main dart, which will return all new archives that were created.

**Code Coverage**
We have updated our CI-flow to include commit-stage code-coverage tests, which allows us to see which part of the services are not tested.

# Changelog for epoch 466725 .. 548959

**Secure Library Audit**
A list of changes have been made to comply with the recent secure library audit.  
The BIP39 API has been changed as recommended, so it should be less likely for future API users to make mistakes using it.  
This means you should change the following function uses.  
`BIP39.passphrase() -> BIP39.generateMnemonic()`  
`BIP39.opCall() -> BIP39.mnemonicToSeed()`  

`BIP39.validateMnemonic()` should now be used in favour of `BIP39.checkMnemonicNumbers()` and `BIP39.mnemonicNumbers()`.  
The new function also does the proper checksum validation.
We misunderstood how the checksum is calculated and that the last word in the mnemonic phrase is used as a checksum and generated based on the remaining bits in the byte sequence of the 11-bit word sequence and the first nibble of the hash sum of the first words.  
Note, this also means that the 12 to 24 words should be a multiple of 3. Which is checked in the `generateMnemonic()`.

We misunderstood `secp256k1_context_randomize()` as a way to obfuscate memory but its intended usage is as a measure against side-channel attacks.
This means that the function is now only called when creating or copying a context.

The full list of notes can be seen here https://docs.tagion.org/#/documents/audit/audit.md  

**DART Cache**
The dart cache is now updated based on new published recorders from the kernel and has been made default handler in the shell.
This should result in faster updates and less load on the core system when requesting updates for recent transactions.
Some changes need to made to the api of TRT request in order to prevent state mismatch between the shell and kernel. 

**TRT hotfix**
Fixed an issue where if the trt would not find any Archives it would not make response and thereby lock up the dartinterface, blocking new incoming requests.

**Account history**
The account history can now be statically calculated based on the info already stored in AccountDetails. This means that the history can now be retrieved when restoring your wallet.
Fixed an issue where used_bills and sent hirpcs were not stored in AccountDetails.

# Changelog for epoch 392368 .. 466725

**TRT enhancement**
The TRT now stores any document containing the `$Y` record meaning all archives with a public key. This enhancement makes the TRT more robust against future updates.

**Self-Test endpoint**
We have created another endpoint in the shell, which can be used for calling other endpoints in the shell. This allows for an easy interface to test the shell endpoints against.

**Recorder subscription event**
It is now possible via NNG, to subscribe to the recorder. This is useful for our cache in the shell, which will allow for faster lookups in the system.

**Mode1 initial work**
We have begun working on a new NNGGossipnet which will be used for a mode1 version of the network. The difference between mode1 and mode0 is that in mode1 the nodes are running in completely separate processes and instead of using inter-process-communication they will be using proper socket connections.  


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
Improved and added documentation for several services and api's. 
Including the TRT, Subscription, Auszahlung, cli & options for neuewelle, architecture overview.
The documentation is as always available on docs.tagion.org. Previously some pages were missing from the online deployment, this should be fixed now.

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

```
version: v1.0.1+dev+dirty
git: git@github.com:tagion/tagion.git
branch: current
hash: 6258adbd9a805a16edb0f748553de00f69bcb76f
revno: 12834
builder_name: Børge
builder_email: boerge@example.com
CC: gcc (GCC) 12.3.0
DC: DMD64 D Compiler v2.105.2
```

As it can be seen it shows that the binary is on top of v1.0.1 with develop and the working tree is dirty when it was compiled.

**.isMethod patch**
We had a problem if you send a hirpc response as a input the service would throw an error. This has been mitigated so that it does not fail now.

**HashGraph startup problem**
We have had a problem with the hashgraph, where it sometimes would not produce any epochs and create an assert on a wavefront. This was because some empty events where not filtered out. This has been fixed so that the startup is completely stable now allowing our pipeline to be more trustworthy.

**Open sourcing**
Regarding open-sourcing the licenses have been updated as well as the CONTRIBUTING.md file.
The github action for creating the ddoc documentation has also been fixed so that it now runs.

# Changelog for week 48/49 2023

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


# Changelog for week 47/48 2023

**Transcript bug**
Our operational tests found a bug where because the order of operations when iterating a hash-map is not guarantees we could end up in a scenario where the nodes would have the same state, but write different archives in different epochs regarding the consensus voting. This has now been fixed.

**Crypto tape-out**
We have had a final review of our secure-modules and they are now in the process of being externally reviewed one more time before go-live.

**Wallet bug**
We have fixed a bug in the wallet where the fee would be calculated incorrectly. This was due to a bug in the `createPayment` function that gathers the bills which are necessary for creating the transaction.

**NNG memory leak**
We encountered a problem with the NNG-http server where it would leak memory when passing a `char*` to a c-function. This only happens when the string is concatenated with another string, which is a lazy operation. When then taking the pointer of this new variable it only points to the "first" part of the string meaning the other part leaks in memory. This problem has now been mitigated by manually allocating the memory using a static buffer which makes sure it is properly cleaned afterwards and creates a fully monolithic pointer.


# Changelog for week 46/47 2023

**Boot from passkeys**
The wave program can now boot from passkeys meaning from stdin, meaning that you can use ex. a GPG key to manage the passwords for the network or a usb.

**Epoch chain**
The Epoch chain implementation is finished, meaning that on each epoch, the epoch including global parameters is written. We have also changed the way that this happens, so that we actually write epochs from the hashgraph immediately and everytime we add a new vote instead of only writing it once. It is completely finished and includes majority votes. This makes the system more resilient, since if it goes down the votes are stored in the database rather than in memory.

**Crypto**
We do no longer scramble the privatekey, but instead set all bits to 0. This provides the same security while being much faster since we do not have to create a system call to `getrandom(2)` each time.

**ActorHandles**
The ActorHandle implementation has been changed so that it is no longer templated, and instead of doing a `locate`, it tries to send immediately to the previous `tid`. If the `tid` does not exist we set the `tid` and try again. This implementation is faster and safer, since we do not have to do a locate each time and handler errors.

**NNG nothrow**
Most of NNG is now marked nothrow, which allows functions above to also inherit the nothrow attribute making error handling more clear.

**Operational test**
A operational test has been created which is essentially a wrapper around a bdd-test which sends a tx from walletA to walletB. This randomly selects two wallets and continuously creates a transaction between these for a specified amount of time.

**General Update from the Core**
We are very happy to announce that all ground components for the network are finished. This means we are going into Tape-Out mode now and will be doing final reviews on everything and have full focus on operational testing of the system.


# Changelog for week 45/46 2023

**Blockfile**
Fixed an error in the blockfile where the cache would be allocated preruntime,
meaning that multiple blockfiles would use the same cache, even running in separate threads;
This was a cause of multiple derived errors, which has now been fixed.

**Crypto**
Default signatures are now Schnorr.
Add xonly public key conversion functions.

**NNG**
fix NNGMessage allocation
add tests with larger messages(1-2MB)

**Shell**
Initial documentation for the shell caching layer has been added.

**AssertError**
There is now a top level catch in each actor thread, which catches AssertErrors and stops the program.
Previously AssertErrors would stop the thread and reach the main thread without being reported or stopping the program.

**Wave**
Add `--option` flag to be able to set individual options.
Can be used with -O to change the options file permanently

**HiRPC error type**
The HiRPC error type has been changes so it's always considered an error, if it's not a method or a result.

**CI**
The CI workflow can now run on any branch.
Testnet workflow cleans old backups & main workflows cleans old artifacts

# Changelog for week 44/45 2023

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

**Fixes & Stability improvements**
 * We have made changes to how the node starts the replicator service. 
 * Improved the way the transcript stores and cleans votes.
 * Removed some unsafe type casts.
 * Fixed error with unflushed DART writes.
 * Created improvements to the Error replies when sending a contract and making a DART read request.
 * Fixed the inputvalidator test, which used the wrong socket type.
 * ...

**Remove legacy code**
We have removed all of the SSL modules.

**CI Improvements**
The CI flow now runs in several steps, so we have better error reporting when and which stage fails.
The workflows times out when a job hangs. And it always produces an artifact so we can inspect the errors.


# Changelog for week 43/44 2023
**Malformed Contract scenarios**
We have implemented various scenarios where the user tries to send an invalid contract. This could be where some fields of the contract are missing. Or when it comes to transactions, the user could send an input that is not a bill, among many others.

**Faucet shell integration**
We have integrated a faucet functionality into the test version of the shell, allowing us to easier test the wallets since they now can request test-tagions.

**Secp256k1 multisig and change of library**
We have updated our library from the secp256k1 library located in bitcoin core to https://github.com/BlockstreamResearch/secp256k1-zkp. The reason why we have made this change, is because we want to support multisig for various parts, and this is a functionality that is good to get into the system before it is running in its final state because it is very difficult to update. We have therefore started to implement schnorr signatures for signing.


# Changelog for week 42/43 2023
**Shell Client**
We have committed a WebClient with TLS support. See [github.com/tagion/nng](http://github.com/tagion/nng) test example test_11_webclient.d. This makes for a very small and easy to use webclient for our CLI wallet among other places. Currently only synchronous GET and POST methods are available.

**HiBONRecord @labels**
We have refactored the way HiBONRecord labels are defined so that it is easier to understand. See the following example:

Now we can do the following:
```D
struct Test {
  @exclude int x;
  @optional Document d;

  mixin HiBONRecord;
}
```

Instead of:
```D
struct Test {
  @label("") int x;
  @label(VOID, true) Document d;

  mixin HiBONRecord;
}
```
**SecureNet Services bug**
We ran into a problem where our securenet would sometimes return that the signature was not valid event though it was. This only happened when running multithreaded and doing it a lot concurrently. The problem was that due to secp256k1 not being thread safe, we were using the same context for all the threads, which of course is not good. Therefore we now pass a shared net down to all services, where each creates its own context. Also services that do not perform any signing by themselves, but purely check signatures like the HiRPC-verifier now create their own SecureNet.

**Consensus Voting**
We have implemented the functionality for sending the signed bullseye around after a DARTModify. The reason for doing this is in order to check that all nodes have the same exact state. If more than 1/3 of the nodes do not agree then they will perform a roll-back of the epoch.


# Changelog for week 41/42 2023
**Shell with HTTP proxy**
The shell has been updated to use our NNG http proxy now so that it is possible to send a transaction through with http. 

**Double spend scenarios**
We are working on different testing scenarios currently, and the last week was spent doing testing around double spending which went very well :-). 

**Subscription Service**
We have implemented a subscription service that wraps our internal subscription and allows external clients to subscribe to different events with NNG. This could for an example be every time we create a modify transaction to the DART.

**Tooling on genesis block**
We have created and updated tools to support functionality for the genesis block. This includes asking the database to retrieve all bills with regex searching among many other things.

**Epoch creator**
The epoch creator has been updated to use true randomness making the communication with other nodes more unpredictable.
This is important for security of the nodes, because it helps prevents malicious actors in constructing for an example coin-round scenarios.

**LEB128 check for invariant numbers**
We only support the shortest form to write numbers with LEB128 in order to make HiBON truly hash invariant. In order to achieve this we have to make sure that the LEB128 number is always represented in the shortest way possible. The number 0x80 and 0x00 are ex. both equal to 0x00.


# Changelog for week 40/41 2023
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
It works by using an archive member named "#name" as the dartindex instead of the hash of the archive.

**Collector Service**
The collector has been updated so that the list it receives of archives is ordered. This makes the logic for the collector much simpler, since it does not have to do unnecessary sorting work.

**Build flow updates**
We are always striving for better workflows in order to minimize time spent compiling etc. This week we have optimized our make flow even more which have drastically reduced our build times.

**HiBON npm package**
We have finished our NPM package, which is now also open-sourced and can be found here: https://www.npmjs.com/package/hibonutil-wrapper.
This allows you to interact with HiBON in node-js. An example of a use case is parsing HiBONJSON into a HiBON structure.
```
  const hibon = new HiBON(JSON.stringify(req.body));
```
We are very excited about this because it will make it easier to use HiBON for all other developers.  

# Changelog for week 39/40 2023
**Merging new services**
The following week was spent gluing the last parts of our new service infrastructure together and further testing of the different components. We can now say that all our different services are communicating with each other and running. This means that refactoring of the service layer is mostly finished now and we are even able to send tagions through the new system.

**DARTInterface service**
We have created a new service for the shell to communicate effiecently with the dart. This is done via a NNGPool that has a fixed number of slots and allows multiple clients to open a REQ/REP socket. The NNGPool then manages when the sockets can bind and get an answer from the dart.
This in return means that the updates for the wallets will be much quicker as they do not have to go through the entire contract execution pipeline.

**TVM service**
We have created a new service for the TVM ("Tagion Virtual Machine"). The service is responsible for executing the instructions in the contract ensuring the contracts are compliant with Consensus Rules.

**BIP39**
We have updated our implementation of BIP39 mnemonic seed phrases to use pkbdf2 as the standard suggests. This is important because it guarantees that if you use the same keys on other wallets you will generate the same seed phrase. 
We did though find the standard implementation of BIP39 to be a bit weird in the sense that it does not use the index of the words in the words list for creating the hash but rather all the words?!. Using the words provides no benefits other than making the implementation more language indenpendent.
Though instead of diverging from the standard we have now implemented it according to the standard as well.

# Changelog for week 38/39 2023
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
We have implemented a new dartCRUD command that can be sent with HiRPC. This command works just like dartRead but instead of returning all the archives it returns a list of all the DARTindices that were not found in the database. This is very useful for ex. checking if the bills in the DART are still present seen from a wallet perspective. 

# Changelog for week 37/38 2023

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


# Changelog for week 36/37 2023

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
Updated the documentation for HiBONJSON and provide samples in hibonutil for easier compatibility testing.
ISO time is now the accepted time format in HiBONJSON as opposed to SDT time

**CRYPTO**
Random generators are seeded with the hardware random functions provided by the OS.

**Epoch Creator**
The epoch creator is the service that drives the hashgraph. 
It's implemented using a shared address-book and tested in mode-0.
The address-book avoids buried state which was a source of several problems previously when bootstrapping the network.

**DART Service**
The DART service has been implemented and CRUD operations tested. 
The service allows several services to access the DART.

**OLD TRANSACTION**
The code for the old transaction mechanism has been separated and moved in to the prior services. This means that the code lives separately and the OLD_TRANSACTION version flag has been removed.



# Changelog for week 34/35 2023

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



# Changelog for week 33/34 2023

**NNG**
We've completed the implementation of asynchronous calls in NNG -Aio, which enhances our system's responsiveness with non-blocking IO capabilities. The integration of NNG into our services has begun, starting with the inputvalidator.

**Build flows**
Our Android build-flows have been refined to compile all components into a single binary, enabling uniform use of a mobile library across the team. This optimisation is achieved through a matrix-run process in GitHub Actions.

**WASM Transpiling**
We can now transpile Wast i32 files to BetterC and automatically convert test specifications into unit tests. This advancement enables comprehensive testing of transpiled BetterC files.

**Hashgraph**
We've improved epoch flexibility in the Hashgraph, aligning with last week's adjustments to "famous" and "witness" definitions. It leads to events ending in epochs earlier, allowing for faster consensus.



# Changelog for week 34/35 2023

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
