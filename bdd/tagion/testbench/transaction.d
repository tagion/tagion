module tagion.testbench.transaction;

import tagion.behaviour.Behaviour;
import tagion.testbench.transaction_features;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.tools.Basic;
import std.traits: moduleName;
import tagion.testbench.tools.utils: Genesis;

mixin Main!(_main, "transaction_features");

int _main(string[] args)
{
    string scenario_name = __MODULE__;

	const number_of_wallets = 7;

	const genesis = [
		Genesis(10, 10_000), 
		Genesis(10, 10_000), 
		Genesis(10, 10_000), 
		Genesis(10, 10_000), 
		Genesis(10, 10_000), 
		Genesis(10, 10_000), 
		Genesis(10, 10_000), 
	];

    auto create_wallets_feature = automation!(create_wallets)();
    create_wallets_feature.GenerateNWallets(scenario_name, number_of_wallets);
    auto create_wallets_context = create_wallets_feature.run;

	auto create_dart_feature = automation!(create_dart)();
    create_dart_feature.GenerateDart(scenario_name, create_wallets_context.GenerateNWallets, genesis);
    auto create_dart_context = create_dart_feature.run;
    return 0;

}
