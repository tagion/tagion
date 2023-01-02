module tagion.testbench.transaction;

import tagion.behaviour.Behaviour;
import tagion.testbench.transaction_features;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.tools.Basic;
import std.traits: moduleName;

mixin Main!(_main, "transaction_features");

int _main(string[] args)
{
    string scenario_name = __MODULE__;

    auto create_wallets_feature = automation!(create_wallets)();
    create_wallets_feature.GenerateNWallets(scenario_name, 7);
    auto create_wallets_context = create_wallets_feature.run;
    return 0;

}