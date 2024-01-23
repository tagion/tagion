<a style="margin: 0 0 0 15px" href="https://tagion.org">
	<img alt="Tagion org" src="/documents/figs/logomark.svg" alt="tagion.org" height="60">
</a>

---

- [Home](README.md)
- [TIPs](documents/TIPs/main.md)
- Network
	- [Modes](documents/architecture/Network_Modes.md)
	- [Architecture](documents/architecture/Network_Architecture.md)
		- [Input Validator](/documents/architecture/InputValidator.md)
		- [HiRPC Verifier](/documents/architecture/HiRPCVerifier.md)
		- [Collector](/documents/architecture/Collector.md)
		- [TVM](/documents/architecture/TVM.md "Tagion Virtual Machine")
		- [Transcript](/documents/architecture/Transcript.md)
		- [Epoch Creator](/documents/architecture/EpochCreator.md)
		- [DART](/documents/architecture/DART.md "Distributed Archive of Random Transactions")
		- [Replicator](/documents/architecture/Replicator.md)
		- [Node Interface](/documents/architecture/NodeInterface.md)
		- [Logger](/documents/architecture/Logger.md)
		- [Logger Subscription](/documents/architecture/LoggerSubscription.md)
		- [Monitor](/documents/architecture/Monitor.md)
		- [Epoch Dump](/documents/architecture/EpochDump.md)
		- [Shell cache](/documents/architecture/DARTCache.md)
		- [TRT](/documents/architecture/TRT.md)

- Protocols
	- [HiBON](documents/protocols/hibon.md)
    - [Contract](/documents/protocols/contract/Contract.md)
        - [Methods](/documents/protocols/contract/hirpcmethods.md)
	    - [Bill](/documents/protocols/contract/Bill.md)
    - DART
		- [Recorder](/documents/modules/dart/recorder.md)
		- [BlockFile and Recycler](/documents/modules/dart/block_file_recycler.md)
	- Wallet
		- [Wallet](/documents/modules/wallet/wallet.md)
        - [Simple payment](/documents/protocols/contract/Transfer.md)
	- Actors
		- [Actor](/documents/modules/actor/actor_requirement.md)
	- Consensus Protocol
		- [Epoch Rules](/documents/protocols/consensus_protocol/EpochRules.md)

- API's
    - [HiBON API](/documents/protocols/api/hibon_api.md)

- Testing
    - [CI/CD](documents/continous_integration_and_delivery/systemic_overview.md)
	- Behaviour tests
		- [BDD_Process](documents/behaviour/BDD_Process.md)
		- [BDDLogger](documents/behaviour/BDDLogger.md)
		- [BDDEnvironment](documents/behaviour/BDDEnvironment.md)
		- [List of behaviour tests](bdd/BDDS.md)

- Tools
	- [blockutil](/src/bin-blockutil/README.md)
	- [hibonutil](/src/bin-hibonutil/README.md)
	- [dartutil](/src/bin-dartutil/README.md)
    - [collider](/src/bin-collider/README.md)
    - [geldbeutel](/src/bin-geldbeutel/README.md)
    - [auszahlung](/src/bin-auszahlung/README.md)

- Network Setup 
    - [Initialize DART](documents/network_setup/initialize_dart.md)
    - [Initialize Genesis](documents/network_setup/initialize_genesis_epoch.md)
    - [Node account](documents/network_setup/minting_and_accounts.md)
- [Modules](src/)
- [Changelog](documents/changelog.md)
