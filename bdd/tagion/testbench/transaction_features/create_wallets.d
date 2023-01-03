module tagion.testbench.transaction_features.create_wallets;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;

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

    int number_of_wallets;
    string module_path;
    string[] wallet_paths;

    this(string module_name, int n)
    {
        this.number_of_wallets = n;
        this.module_path = env.bdd_log.buildPath(module_name);
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
            const wallet_path = module_path.buildPath(format("wallet_%s", i));

            mkdirRecurse(wallet_path);

            immutable wallet_command = [
                tools.tagionwallet,
                "-x", 
                "1111",
                "--generate-wallet",
                "--questions",
                "1,2,3,4",
                "--answers",
                "1,2,3,4",
            ];

            auto pipes = pipeProcess(wallet_command, Redirect.all, null, Config.detached, wallet_path);

            string[] errors;
            foreach (line; pipes.stderr.byLine)
                errors ~= line.idup;

            check(errors.length == 0, format("Error: %s", errors));
            writefln("%s", wallet_path);
            wallet_paths ~= wallet_path;
        }

        return result_ok;
    }

    @Then("check if the wallet can be activated with the pincode.")
    Document pincode() @trusted
    {
        for(int i=0; i<number_of_wallets; i++)
        {
            immutable wallet_command = [tools.tagionwallet, "-x", "1111"]; 
            auto pipes = pipeProcess(wallet_command, Redirect.all, null, Config.detached, wallet_paths[i]);
            
            string[] errors;
            foreach (line; pipes.stderr.byLine)
                errors ~= line.idup;

            check(errors.length == 0, format("Error: %s", errors));
        }
        return result_ok;
    }

}
