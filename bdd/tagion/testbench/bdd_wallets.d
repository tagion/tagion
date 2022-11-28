module tagion.testbench.bdd_wallets;
import tagion.behaviour.Behaviour;
import tagion.testbench.wallet;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.tools.Basic;
import tagion.testbench.wallet;

mixin Main!(_main, "wallet");

int _main(string[] args)
{
    auto wallet_feature = automation!(Wallet_generation)();
    auto wallet_context = wallet_feature.run;

    auto dart_feature = automation!(Boot_wallet)();
    dart_feature.GenerateDartboot(wallet_context.SevenWalletsWillBeGenerated);
    auto dart_context = dart_feature.run;

    auto start_network_feature = automation!(Start_network)();
    start_network_feature.StartNetworkInModeone(
        wallet_context.SevenWalletsWillBeGenerated, dart_context.GenerateDartboot);
    auto start_network_context = start_network_feature.run;

    return 0;

}
