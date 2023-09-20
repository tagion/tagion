<a style="margin: 0 0 0 15px" href="https://tagion.org">
	<img alt="Tagion org" src="/documents/figs/logomark.svg" alt="tagion.org" height="60">
</a>

---

- [Home](README.md)
- Continous Integration / Continours Delivery
	- [Systemic overview](documents/continous_integration_and_delivery/systemic_overview.md)
- Network
	- [Modes](documents/architecture/Network_Modes.md)
	- [bootstrap](documents/architecture/Network_bootstrap.md)
	- [Architecture](documents/architecture/Network_Architecture.md)
		- [Tagion](/documents/architecture/Tagion.md)
		- [Tagion Factory](/documents/architecture/TagionFactory.md)
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

- Protocols
	- [HiBON](documents/protocols/hibon/README.md)
		- [Hash_invariant_Binary_Object_Notation](documents/protocols/hibon/Hash_invariant_Binary_Object_Notation.md)
		- [Hash_invariant_Remote_Procedure_Call](documents/protocols/hibon/Hash_invariant_Remote_Procedure_Call.md)
		- [HiBON_JSON_format](/documents/protocols/hibon/HiBON_JSON_format.md)
		- [HiBON_LEB128](/documents/protocols/hibon/HiBON_LEB128.md)
		- [HiBON_Record](/documents/protocols/hibon/HiBON_Record.md)
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

- Tagion API's
    - [HiBON API](/documents/protocols/api/hibon_api.md)

- Testing
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

- Project goals
	- [Goals Q1-Q2 2023](documents/project/project_goals_2023_Q1_Q2.md)

- [Modules](src/)
- [Relase_notes](documents/Relase_notes.md)
