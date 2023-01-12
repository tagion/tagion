module tagion.testbench.transaction_features.create_wallets;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;
import tagion.testbench.tools.wallet;
import tagion.testbench.tools.BDDOptions;
import tagion.logger.Logger;


import std.typecons : Tuple;
import std.stdio;
import std.process;
import std.path;
import std.format;
import std.file;

enum feature = Feature("Generate wallets.", []);

alias FeatureContext = Tuple!(GenerateNWallets, "GenerateNWallets", FeatureGroup*, "result");

@safe @Scenario("Generate n wallets.", [])
class GenerateNWallets
{
    TagionWallet[] wallets;
    int number_of_wallets;
    string module_path;

    this(BDDOptions bdd_options)
    {
        this.number_of_wallets = bdd_options.genesis_wallets.number_of_wallets;
        this.module_path = env.bdd_log.buildPath(bdd_options.scenario_name);
    }

    @Given("i have n pincodes and questions")
    Document questions() @trusted
    { 
        return result_ok;
    }

    @When("the wallets are created save the pin.")
    Document pin() @trusted
    {
        mkdirRecurse(module_path);

        for (int i = 0; i < number_of_wallets; i++)
        {
            immutable wallet_path = module_path.buildPath(format("wallet_%s", i));
            mkdirRecurse(wallet_path);
            log.register("Create wallets");
            writefln("Wallet %s path : %s", i, wallet_path);

            TagionWallet wallet = TagionWallet(wallet_path);
            immutable cmd = wallet.generateWallet();
            check(cmd.status == 0, format("Command failed, Error: %s", cmd.output));
            wallets ~= wallet;
        }

        return result_ok;
    }

    @Then("check if the wallet can be activated with the pincode.")
    Document pincode() @trusted
    {
        foreach(wallet; wallets) { 
            immutable cmd = wallet.unlock();
            check(cmd.status == 0, format("Command failed, Error: %s", cmd.output));
        }
        return result_ok;
    }

}
