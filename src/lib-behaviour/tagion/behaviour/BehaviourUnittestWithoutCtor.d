module tagion.behaviour.BehaviourUnittestWithoutCtor;

import tagion.behaviour.BehaviourFeature;

/// This module is only use to support the unittest
version (unittest) {
    import std.format;
    import std.process;
    import std.typecons : Tuple;
    import tagion.behaviour.BehaviourException;
    import tagion.behaviour.BehaviourResult;
    import tagion.hibon.Document;
    import tagion.hibon.HiBON;

    bool pass; /// Pass the test
    bool pass_one; /// Pass only one scenario
    bool pass_some; /// Pass some of the scenario

    @safe
    Document result(string test) {
        if (pass) {
            auto h = new HiBON;
            h["test"] = test;
            Result result;
            result.outcome = Document(h);
            return result.toDoc;
        }
        // Return a docunent which is not a Result
        return Document();
    }

    enum feature = Feature("Some awesome feature should print some cash out of the blue");
    alias FeatureContext = Tuple!(
            Some_awesome_feature, "Some_awesome_feature",
            Some_awesome_feature_bad_format_double_property, "Some_awesome_feature_bad_format_double_property",
            FeatureGroup*, "result"
    );
    // Behavioral examples
    @safe
    @Scenario("Some awesome money printer")
    class Some_awesome_feature {
        uint count;
        string text;

        @Given("the card is valid")
        Document is_valid() {
            if (pass_some) {
                pass = true;
            }
            count++;
            return result(__FUNCTION__);
        }

        @Given("the account is in credit")
        Document in_credit() {
            count++;
            return result(__FUNCTION__);
        }

        @Given("the dispenser contains cash")
        Document contains_cash() {
            count++;
            return result(__FUNCTION__);
        }

        @When("the Customer request cash")
        Document request_cash() {
            if (pass_some) {
                pass = false;
            }
            count++;
            return result(__FUNCTION__);
        }

        @Then("the account is debited")
        Document is_debited() {
            count++;
            return result(__FUNCTION__);
        }

        @Then("the cash is dispensed")
        Document is_dispensed() {
            count++;
            return result(__FUNCTION__);
        }

        @But("if the Customer does not take his card, then the card must be swollowed")
        Document swollow_the_card() {
            count++;
            return result(__FUNCTION__);
        }

        void helper_function() {
        }
    }

    @safe
    @Scenario("Some money printer which is controlled by a bankster")
    class Some_awesome_feature_bad_format_double_property {
        uint count;

        @Given("the card is valid")
        Document is_valid() {
            if (pass_some || pass_one) {
                pass = true;
            }
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

        @Then("the cash is dispensed")
        Document is_dispensed() {
            if (pass_some) {
                pass = false;
            }
            count++;
            return result(__FUNCTION__);
        }
    }

}
