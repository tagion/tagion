module tagion.testbench.bdd_wallets;
import tagion.behaviour.Behaviour;
import tagion.testbench.wallet;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.tools.Basic;
import tagion.testbench.wallet;

mixin Main!(_main, "wallet");

int _main(string[] args) {
    auto wallet_feature = automation!(Wallet_generation)();
    auto wallet_context = wallet_feature.run;

    auto dart_feature = automation!(Boot_wallet)();
    dart_feature.GenerateDartboot(wallet_context.SevenWalletsWillBeGenerated);

    auto dart_context = dart_feature.run;
    //    auto wallet_invoice = automation!(Create_wallet_dart)();

    // wallet_invoice.GenerateGENESISInvoice(wallet_result);

    // auto genesis_invoice_result = wallet_invoice.run();
    // GenerateGENESISInvoice x;
    // x = new GenerateGENESISInvoice(wallet_result);
    //    pragma(msg, typeof(wallet_invoice));

    //    "/tmp/genesis_invoice_result.hibon".fwrite(genesis_invoice_result);

    return 0;

}
