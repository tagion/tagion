module tagion.testbench.end2end_features.create_wallets;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;


import std.typecons : Tuple;
import std.stdio;
import std.process;
import std.path;
import std.format;

enum feature = Feature("Generate wallets.", []);

alias FeatureContext = Tuple!(GenerateNWallets, "GenerateNWallets", FeatureGroup*, "result");

@safe @Scenario("Generate n wallets.", [])
class GenerateNWallets {

    int number_of_wallets;

    this(int n) {
        this.number_of_wallets = n;
    }

    @Given("i have n pincodes and questions")
    Document questions() {



        
        writefln("NUMBER OF WALLETS %s", number_of_wallets);
        
        return result_ok;
    }

    @Given("i create wallets.")
    Document wallets() {
        const wallet_path = env.bdd_log.buildPath(format("wallet_%s", 1));
        writefln("wallet_path: %s", wallet_path);

        immutable wallet_command = [tools.tagionwallet,
                                    "-x 1111",
                                    "--generate-wallet",
                                    "--questions 1,2,3,4",
                                    "--answers 1,2,3,4",
                                    wallet_path];
        auto result = execute(wallet_command);

        check(result.status == 0, "Error generating wallet");
        return result_ok;
    }

    @When("the wallets are created save the pin.")
    Document pin() {
        return Document();
    }

    @Then("check if the wallet can be activated with the pincode.")
    Document pincode() {
        return Document();
    }

}
