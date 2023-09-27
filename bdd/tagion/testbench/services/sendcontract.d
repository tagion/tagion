module tagion.testbench.services.sendcontract;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "send a contract to the network.",
            []);

alias FeatureContext = Tuple!(
        SendASingleTransactionFromAWalletToAnotherWallet, "SendASingleTransactionFromAWalletToAnotherWallet",
        FeatureGroup*, "result"
);

@safe @Scenario("send a single transaction from a wallet to another wallet.",
        [])
class SendASingleTransactionFromAWalletToAnotherWallet {

    @Given("i have a dart database with already existing bills linked to wallet1.")
    Document wallet1() {
        return Document();
    }

    @Given("i make a payment request from wallet2.")
    Document wallet2() {
        return Document();
    }

    @When("wallet1 pays contract to wallet2 and sends it to the network.")
    Document network() {
        return Document();
    }

    @Then("wallet2 should receive the payment.")
    Document payment() {
        return Document();
    }

}
