module tagion.testbench.bdd_wallets;
import tagion.behaviour.Behaviour;
import tagion.testbench.wallet;
import tagion.hibon.HiBONRecord : fwrite;

import tagion.tools.Basic;
import tagion.testbench.wallet;
import tagion.testbench.Environment;
import std.path;
import std.file : mkdirRecurse;
import std.process;



mixin Main!(_main, "wallet");

int _main(string[] args) {
    auto wallet_feature = automation!(Wallet_generation)();
    auto wallet_result = wallet_feature.run;


    mkdirRecurse(env.bdd_results);
    const result_file =  buildPath(env.bdd_results, "wallet_result.hibon");
    result_file.fwrite(wallet_result);

    execute([tools.hibonutil, "-p", result_file]);

    // "/tmp/wallet_result.hibon".fwrite(wallet_result);


//    auto wallet_invoice = automation!(Create_wallet_dart)();

    // wallet_invoice.GenerateGENESISInvoice(wallet_result);
    
    // auto genesis_invoice_result = wallet_invoice.run();
    // GenerateGENESISInvoice x;
    // x = new GenerateGENESISInvoice(wallet_result);
//    pragma(msg, typeof(wallet_invoice));



//    "/tmp/genesis_invoice_result.hibon".fwrite(genesis_invoice_result);


    return 0;

}
