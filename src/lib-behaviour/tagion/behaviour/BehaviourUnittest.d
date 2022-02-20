module tagion.behaviour.BehaviourUnittest;

import tagion.behaviour.BehaviourBase;
/// This module is only use to support the unittest
version(unittest) {
    import tagion.hibon.HiBON;
    import tagion.hibon.Document;
    enum feature = Feature("Some awesome feature should print some cash out of the blue");
    // Behavioral examples
    @Scenario("Some awesome money printer")
        class Some_awesome_feature {
            static Document result(string test) {
                auto h=new HiBON;
                h["test"] = test;
                return Document(h);
            }
            uint count;
            @Given("the card is valid")
            Document is_valid() {
                count++;
                return result(__FUNCTION__);
            }
            @And("the account is in credit")
            Document in_credit() {
                count++;
                return result(__FUNCTION__);
            }
            @And("the dispenser contains cash")
            Document contains_cash() {
                count++;
                return result(__FUNCTION__);
            }
            @When("the Customer request cash")
            Document request_cash() {
                count++;
                return result(__FUNCTION__);
            }
            @Then("the account is debited")
            Document is_debited() {
                count++;
                return result(__FUNCTION__);
            }
            @And("the cash is dispensed")
            Document is_dispensed() {
                count++;
                return result(__FUNCTION__);
            }
            void helper_function() {
            }
        }

    @Scenario("Some money printer which is controlled by a bankster")
        class Some_awesome_feature_bad_format_double_propery {
            @Given("the card is valid")
            Document is_valid() {
                return Document();
            }
            @Given("the card is valid (should not have two Given)")
            Document is_valid_bad_one() {
                return Document();
            }
            @When("the Customer request cash")
            Document request_cash() {
                return Document();
            }
            @When("the Customer request cash (Should not have two When)")
            Document request_cash_bad_one() {
                return Document();
            }
            @Then("the account is debited")
            Document is_debited() {
                return Document();
            }
            @Then("the account is debited (Should not have two Then)")
            Document is_debited_bad_one() {
                return Document();
            }
            @And("the cash is dispensed")
            Document is_dispensed() {
                return Document();
            }
        }

    @Scenario("Some money printer which has run out of paper")
        class Some_awesome_feature_bad_format_missing_given {
            @Then("the account is debited (Should not have two Then)")
            Document is_debited_bad_one() {
                return Document();
            }
            @And("the cash is dispensed")
            Document is_dispensed() {
                return Document();
            }
        }

    @Scenario("Some money print which is gone wild and prints toilet paper")
        class Some_awesome_feature_bad_format_missing_then {
            @Given("the card is valid")
            Document is_valid() {
                return Document();
            }
        }


}
