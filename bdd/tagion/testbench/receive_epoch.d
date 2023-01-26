module tagion.testbench.receive_epoch;

import tagion.behaviour.Behaviour;
import tagion.testbench.functional;
import tagion.hibon.HiBONRecord : fwrite;
import std.stdio;

import tagion.tools.Basic;
import std.traits : moduleName;
import tagion.testbench.tools.BDDOptions;

import std.format;

mixin Main!(_main);

int _main(string[] args)
{
    string scenario_name = __MODULE__;

    BDDOptions bdd_options;
    setDefaultBDDOptions(bdd_options);
    bdd_options.scenario_name = __MODULE__;

    bdd_options.save(format("/tmp/%s.json", scenario_name));

    auto create_wallets_feature = automation!(create_wallets)();
    create_wallets_feature.GenerateNWallets(bdd_options);
    auto create_wallets_context = create_wallets_feature.run;

    auto create_dart_feature = automation!(create_dart)();
    create_dart_feature.GenerateDart(create_wallets_context.GenerateNWallets, bdd_options);
    auto create_dart_context = create_dart_feature.run;

    auto create_network_in_mode_one_feature = automation!(create_network_in_mode_one)();
    create_network_in_mode_one_feature.CreateNetworkWithNAmountOfNodesInModeone(create_dart_context.GenerateDart,
        create_wallets_context.GenerateNWallets, bdd_options);
    auto create_network_in_mode_one_context = create_network_in_mode_one_feature.run;


    auto receive_epoch_feature = automation!(receive_epoch_test)();
    receive_epoch_feature.Receiveepoch(create_network_in_mode_one_context.CreateNetworkWithNAmountOfNodesInModeone, bdd_options);
    auto receive_epoch_context = receive_epoch_feature.run;

    auto kill_network_feature = automation!(kill_network)();
    kill_network_feature.KillTheNetworkWithPIDS(
        create_network_in_mode_one_context.CreateNetworkWithNAmountOfNodesInModeone, bdd_options);
    auto kill_network_context = kill_network_feature.run;

    return 0;

}