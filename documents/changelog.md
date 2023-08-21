# Changelog week 33-34
## NNG:
We've completed the implementation of asynchronous calls in NNG, which in return enhances our system's responsiveness with non-blocking IO capabilities. The integration of NNG into our services has also begun, starting with the inputvalidator.
## Buildflows:
Our Android build-flows have been refined to compile all components into a single binary, enabling uniform use of a mobile library across the team. This optimization is achieved through a matrix-run process in GitHub Actions.
## WASM Transpiling:
We can now transpile Wast i32 files to BetterC and automatically convert test specifications into unittests. This advancement enables comprehensive testing of transpiled BetterC files.
## Hashgraph:
We've improved epoch flexibility in the Hashgraph, aligning with last weeks adjustments to "famous" and "witness" definitions. This leads to events ending up in epochs earlier, allowing for faster consensus.
