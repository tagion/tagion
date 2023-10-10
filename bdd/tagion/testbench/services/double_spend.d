module tagion.testbench.services.double_spend;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.wallet.SecureWallet : SecureWallet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;

alias StdSecureWallet = SecureWallet!StdSecureNet;
enum feature = Feature(
            "double spend scenarios",
            []);

alias FeatureContext = Tuple!(
        SameInputsSpendOnOneContract, "SameInputsSpendOnOneContract",
        OneContractWhereSomeBillsAreUsedTwice, "OneContractWhereSomeBillsAreUsedTwice",
        SameContractDifferentNodes, "SameContractDifferentNodes",
        SameContractInDifferentEpochs, "SameContractInDifferentEpochs",
        SameContractInDifferentEpochsDifferentNode, "SameContractInDifferentEpochsDifferentNode",
        TwoContractsSameOutput, "TwoContractsSameOutput",
        BillAge, "BillAge",
        AmountOnOutputBills, "AmountOnOutputBills",
        FeatureGroup*, "result"
);

@safe @Scenario("Same inputs spend on one contract",
        [])
class SameInputsSpendOnOneContract {

    @Given("i have a malformed contract with two inputs which are the same")
    Document same() {
        return Document();
    }

    @When("i send the contract to the network")
    Document network() {
        return Document();
    }

    @Then("the inputs should be deleted from the dart.")
    Document dart() {
        return Document();
    }

}

@safe @Scenario("one contract where some bills are used twice.",
        [])
class OneContractWhereSomeBillsAreUsedTwice {

    @Given("i have a malformed contract with three inputs where to are the same.")
    Document same() {
        return Document();
    }

    @When("i send the contract to the network")
    Document network() {
        return Document();
    }

    @Then("all the inputs should be deleted from the dart.")
    Document dart() {
        return Document();
    }

}

@safe @Scenario("Same contract different nodes.",
        [])
class SameContractDifferentNodes {

    @Given("i have a correctly signed contract.")
    Document contract() {
        return Document();
    }

    @When("i send the same contract to two different nodes.")
    Document nodes() {
        return Document();
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("Same contract in different epochs.",
        [])
class SameContractInDifferentEpochs {

    @Given("i have a correctly signed contract.")
    Document contract() {
        return Document();
    }

    @When("i send the contract to the network in different epochs to the same node.")
    Document node() {
        return Document();
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("Same contract in different epochs different node.",
        [])
class SameContractInDifferentEpochsDifferentNode {

    @Given("i have a correctly signed contract.")
    Document contract() {
        return Document();
    }

    @When("i send the contract to the network in different epochs to different nodes.")
    Document nodes() {
        return Document();
    }

    @Then("the first contract should go through and the second one should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("Two contracts same output",
        [])
class TwoContractsSameOutput {

    @Given("i have a payment request containing a bill.")
    Document bill() {
        return Document();
    }

    @When("i pay the bill from two different wallets.")
    Document wallets() {
        return Document();
    }

    @Then("only one output should be produced.")
    Document produced() {
        return Document();
    }

}

@safe @Scenario("Bill age",
        [])
class BillAge {

    @Given("i pay a contract where the output bills timestamp is newer than epoch_time + constant.")
    Document constant() {
        return Document();
    }

    @When("i send the contract to the network.")
    Document network() {
        return Document();
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("Amount on output bills",
        [])
class AmountOnOutputBills {

    @Given("i create a contract with outputs bills that are smaller or equal to zero.")
    Document zero() {
        return Document();
    }

    @When("i send the contract to the network.")
    Document network() {
        return Document();
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        return Document();
    }

}
