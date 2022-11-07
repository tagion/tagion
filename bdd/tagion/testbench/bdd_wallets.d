module tagion.testbench.bdd_wallets;
import tagion.behaviour.Behaviour;
import tagion.testbench.wallet;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.tools.Basic;


mixin Main!(_main, "wallet");

int _main(string[] args) {
    auto wallet_feature = automation!(Wallet_generation)();
    auto result = wallet_feature.run;

    "/tmp/result.hibon".fwrite(result);

    return 0;

}