# Changelog for Week 33/34

**NNG**
We've completed the implementation of asynchronous calls in NNG -Aio, which enhances our system's responsiveness with non-blocking IO capabilities. The integration of NNG into our services has begun, starting with the inputvalidator.

**Build flows**
Our Android build-flows have been refined to compile all components into a single binary, enabling uniform use of a mobile library across the team. This optimisation is achieved through a matrix-run process in GitHub Actions.

**WASM Transpiling**
We can now transpile Wast i32 files to BetterC and automatically convert test specifications into unit tests. This advancement enables comprehensive testing of transpiled BetterC files.

**Hashgraph**
We've improved epoch flexibility in the Hashgraph, aligning with last week's adjustments to "famous" and "witness" definitions. It leads to events ending in epochs earlier, allowing for faster consensus.