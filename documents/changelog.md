# Changelog for Week 33/34

**NNG**
We've completed the implementation of asynchronous calls in NNG -Aio, which enhances our system's responsiveness with non-blocking IO capabilities. The integration of NNG into our services has begun, starting with the inputvalidator.

**Build flows**
Our Android build-flows have been refined to compile all components into a single binary, enabling uniform use of a mobile library across the team. This optimisation is achieved through a matrix-run process in GitHub Actions.

**WASM Transpiling**
We can now transpile Wast i32 files to BetterC and automatically convert test specifications into unit tests. This advancement enables comprehensive testing of transpiled BetterC files.

**Hashgraph**
We've improved epoch flexibility in the Hashgraph, aligning with last week's adjustments to "famous" and "witness" definitions. It leads to events ending in epochs earlier, allowing for faster consensus.



# Changelog for Week 34/35

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
