module tagion.behaviour.BehaviourUnittest;

import tagion.behaviour.BehaviourBase;
/// This module is only use to support the unittest
version(unittest) {
    enum feature = Feature("Some awesome feature should print some cash out of the blue");
    // Behavioral examples
    @Scenario("Some awesome money printer")
        class Some_awesome_featureT(bool[6] returns) {
            uint count;
            @Given("the card is valid")
            bool is_valid() {
                count++;
                return returns[0];
            }
            @And("the account is in credit")
            bool in_credit() {
                count++;
                return returns[1];
            }
            @And("the dispenser contains cash")
            bool contains_cash() {
                count++;
                return returns[2];
            }
            @When("the Customer request cash")
            bool request_cash() {
                count++;
                return returns[3];
            }
            @Then("the account is debited")
            bool is_debited() {
                count++;
                return returns[4];
            }
            @And("the cash is dispensed")
            bool is_dispensed() {
                count++;
                return returns[5];
            }
            void helper_function() {
            }
        }

    alias Some_awesome_feature = Some_awesome_featureT!([false, false, false, false, false, false]);

    alias Some_awesome_feature_all_implemented = Some_awesome_featureT!([true, true, true, true, true, true]);

    @Scenario("Some money printer which is controlled by a bankster")
        class Some_awesome_feature_bad_format_double_propery {
            @Given("the card is valid")
            bool is_valid() {
                return false;
            }
            @Given("the card is valid (should not have two Given)")
            bool is_valid_bad_one() {
                return false;
            }
            @When("the Customer request cash")
            bool request_cash() {
                return false;
            }
            @When("the Customer request cash (Should not have two When)")
            bool request_cash_bad_one() {
                return false;
            }
            @Then("the account is debited")
            bool is_debited() {
                return false;
            }
            @Then("the account is debited (Should not have two Then)")
            bool is_debited_bad_one() {
                return false;
            }
            @And("the cash is dispensed")
            bool is_dispensed() {
                return false;
            }
        }

    @Scenario("Some money printer which has run out of paper")
        class Some_awesome_feature_bad_format_missing_given {
            @Then("the account is debited (Should not have two Then)")
            bool is_debited_bad_one() {
                return false;
            }
            @And("the cash is dispensed")
            bool is_dispensed() {
                return false;
            }
        }

    @Scenario("Some money print which is gone wild and prints toilet paper")
        class Some_awesome_feature_bad_format_missing_then {
            @Given("the card is valid")
            bool is_valid() {
                return false;
            }
        }


}
