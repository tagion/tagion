module tagion.testbench.end2end;

import tagion.behaviour.Behaviour;
import tagion.testbench.end2end_features;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.tools.Basic;

mixin Main!(_main, "end2end_features");

int _main(string[] args)
{

    auto create_wallets = automation!(create_wallets)();
    auto create_wallets_context = create_wallets.run;
    return 0;

}