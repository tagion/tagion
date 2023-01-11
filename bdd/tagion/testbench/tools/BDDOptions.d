module tagion.testbench.tools.BDDOptions;

import tagion.utils.JSONCommon;
import tagion.testbench.tools.utils : Genesis;
import tagion.testbench.tools.BDDConstants;

struct BDDOptions
{

    BDDConstants constants;

    mixin JSONCommon;

    struct GenesisWallets
    {
        uint number_of_wallets;
        Genesis[] wallets;
        mixin JSONCommon;
    }

    GenesisWallets genesis_wallets;

    mixin JSONConfig;
}

void setDefaultBDDOptions(ref BDDOptions bdd_options)
{
    with (bdd_options)
    {
        with (bdd_options.constants)
        {
            MAX_EPOCHS = 8;
        }
        with (bdd_options.genesis_wallets)
        {
            number_of_wallets = 7;
            wallets = [
                Genesis(1, 10_000),
                Genesis(1, 10_000),
                Genesis(1, 10_000),
                Genesis(1, 10_000),
                Genesis(1, 10_000),
                Genesis(1, 10_000),
                Genesis(1, 10_000),
            ];
        }

    }
}
