module tagion.testbench.double_spend;

import tagion.behaviour.Behaviour;
import tagion.testbench.transaction_features;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.tools.Basic;
import std.traits : moduleName;
import tagion.testbench.tools.utils : Genesis;
import tagion.testbench.tools.BDDOptions;

import std.format;

mixin Main!(_main, "double_spend_test");

int _main(string[] args)
{
    string scenario_name = __MODULE__;

    BDDOptions bdd_options;
    setDefaultBDDOptions(bdd_options);
    bdd_options.network.increase_port = 5000;
    bdd_options.network.tx_increase_port = 10900;

    bdd_options.scenario_name = __MODULE__;

    bdd_options.save(format("/tmp/%s.json", scenario_name));

    auto create_wallets_feature = automation!(create_wallets)();
    create_wallets_feature.GenerateNWallets(bdd_options);
    auto create_wallets_context = create_wallets_feature.run;

    auto create_dart_feature = automation!(create_dart)();
    create_dart_feature.GenerateDart(create_wallets_context.GenerateNWallets, bdd_options);
    auto create_dart_context = create_dart_feature.run;

    auto create_network_feature = automation!(create_network)();
    create_network_feature.CreateNetworkWithNAmountOfNodesInModeone(create_dart_context.GenerateDart,
        create_wallets_context.GenerateNWallets, bdd_options);
    auto create_network_context = create_network_feature.run;

    auto double_spend_feature = automation!(create_double_spend);

    double_spend_feature.DoubleSpendSameWallet(create_wallets_context.GenerateNWallets,
    create_network_context.CreateNetworkWithNAmountOfNodesInModeone,
    bdd_options,
    );

    auto double_spend_context = double_spend_feature.run;

	auto kill_network_feature = automation!(kill_network)();
	kill_network_feature.KillTheNetworkWithPIDS(
		create_network_context.CreateNetworkWithNAmountOfNodesInModeone);
	auto kill_network_context = kill_network_feature.run;

    return 0;

}
