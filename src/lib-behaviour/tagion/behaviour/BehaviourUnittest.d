module tagion.behaviour.BehaviourUnittest;

import tagion.behaviour.BehaviourFeature;

/// This module is only use to support the unittest
version (unittest) {
    import std.format;
    import std.process;
    import tagion.hibon.Document;
    import tagion.hibon.HiBON;

    version (none) {
        immutable(string) REPOROOT;
        shared static this() {
            REPOROOT = environment.get(REPOROOT.stringof, null);
            if (REPOROOT is null) {

                const gitrepo = execute(["git", "rev-parse", "--show-toplevel"]);
                REPOROOT = gitrepo.output;
            }
            assert(REPOROOT, format!"%s must be defined"(REPOROOT.stringof));
        }
    }
    @safe
    Document result(string test) {
        auto h = new HiBON;
        h["test"] = test;
        return Document(h);
    }

    enum feature = Feature("Some awesome feature should print some cash out of the blue");
    // Behavioral examples
    @safe
    @Scenario("Some awesome money printer")
    class Some_awesome_feature {
        uint count;
        @Given("the card is valid")
        Document is_valid() {
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
        @Given("the card is valid")
        Document is_valid() {
            return Document();
        }

        @When("the Customer request cash")
        Document request_cash() {
            return Document();
        }

        @Then("the account is debited")
        Document is_debited() {
            return Document();
        }

        @Then("the cash is dispensed")
        Document is_dispensed() {
            return Document();
        }
    }

    @safe
    @Scenario("Some money printer which has run out of paper")
    class Some_awesome_feature_bad_format_missing_given {
        @Then("the account is debited ")
        Document is_debited_bad_one() {
            import std.exception;

            throw new Exception("Bad debit");
            return Document();
        }

        @Then("the cash is dispensed")
        Document is_dispensed() {
            return Document();
        }
    }

    @safe
    @Scenario("Some money printer which is gone wild and prints toilet paper")
    class Some_awesome_feature_bad_format_missing_then {
        @Given("the card is valid")
        Document is_valid() {
            assert(0);
            return Document();
        }
    }

}

@safe
struct This_is_not_a_scenario {
}
