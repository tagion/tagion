module tagion.testbench.services.malformed_contract;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

enum feature = Feature(
            "malformed contracts",
            []);

alias FeatureContext = Tuple!(
        ContractTypeWithoutCorrectInformation, "ContractTypeWithoutCorrectInformation",
        InputsAreNotBillsInDart, "InputsAreNotBillsInDart",
        NegativeAmountAndZeroAmountOnOutputBills, "NegativeAmountAndZeroAmountOnOutputBills",
        FeatureGroup*, "result"
);

@safe @Scenario("contract type without correct information",
        [])
class ContractTypeWithoutCorrectInformation {

    @Given("i have a malformed signed contract where the type is correct but the fields are wrong.")
    Document wrong() {
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

@safe @Scenario("inputs are not bills in dart",
        [])
class InputsAreNotBillsInDart {

    @Given("i have a malformed contract where the inputs are another type than bills.")
    Document bills() {
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

@safe @Scenario("Negative amount and zero amount on output bills.",
        [])
class NegativeAmountAndZeroAmountOnOutputBills {

    @Given("i have three contracts. One with output that is zero. Another where it is negative. And one with a negative and a valid output.")
    Document output() {
        return Document();
    }

    @When("i send the contracts to the network.")
    Document network() {
        return Document();
    }

    @Then("the contracts should be rejected.")
    Document rejected() {
        return Document();
    }

}
