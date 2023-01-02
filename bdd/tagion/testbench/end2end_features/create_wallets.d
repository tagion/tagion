module tagion.testbench.end2end_features.create_wallets;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;

enum feature = Feature("Generate wallets.", []);

alias FeatureContext = Tuple!(GenerateNWallets, "GenerateNWallets", FeatureGroup*, "result");

@safe @Scenario("Generate n wallets.", [])
class GenerateNWallets {

    @Given("i have n pincodes and questions")
    Document questions() {
        

        return result_ok;
    }

    @Given("i create wallets.")
    Document wallets() {
        return Document();
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
