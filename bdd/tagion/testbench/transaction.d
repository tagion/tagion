module tagion.testbench.transaction;

import tagion.behaviour.Behaviour;
import tagion.testbench.transaction_features;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.tools.Basic;
import std.traits : moduleName;
import tagion.testbench.tools.utils : Genesis;
import tagion.testbench.tools.BDDOptions;

import std.format;

mixin Main!(_main, "transaction_features");

int _main(string[] args)
{
	string scenario_name = __MODULE__;


	BDDOptions bdd_options;
	setDefaultBDDOptions(bdd_options);
	bdd_options.scenario_name = __MODULE__;

	bdd_options.save(format("/tmp/%s.json", scenario_name));

	const genesis = bdd_options.genesis_wallets.wallets;
	const number_of_wallets = bdd_options.genesis_wallets.number_of_wallets;
	const number_of_nodes = bdd_options.network.number_of_nodes;

	auto create_wallets_feature = automation!(create_wallets)();
	create_wallets_feature.GenerateNWallets(bdd_options);
	auto create_wallets_context = create_wallets_feature.run;

	auto create_dart_feature = automation!(create_dart)();
	create_dart_feature.GenerateDart(scenario_name, create_wallets_context.GenerateNWallets, genesis);
	auto create_dart_context = create_dart_feature.run;

	auto create_network_feature = automation!(create_network)();
	create_network_feature.CreateNetworkWithNAmountOfNodesInModeone(scenario_name, create_dart_context.GenerateDart,
		create_wallets_context.GenerateNWallets,
		genesis,
		number_of_nodes,);
	auto create_network_context = create_network_feature.run;

	auto create_transaction_feature = automation!(create_transaction)();
	create_transaction_feature.CreateTransaction(scenario_name,
		create_wallets_context.GenerateNWallets,
		create_network_context.CreateNetworkWithNAmountOfNodesInModeone,
		genesis,
	);
	auto create_transaction_context = create_transaction_feature.run;

	auto kill_network_feature = automation!(kill_network)();
	kill_network_feature.KillTheNetworkWithPIDS(
		create_network_context.CreateNetworkWithNAmountOfNodesInModeone);
	auto kill_network_context = kill_network_feature.run;

	return 0;

}
