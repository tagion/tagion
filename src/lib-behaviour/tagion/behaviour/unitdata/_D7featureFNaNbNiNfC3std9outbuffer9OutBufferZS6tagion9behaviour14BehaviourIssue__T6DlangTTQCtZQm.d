module tagion.behaviour.BehaviourUnittest;
// Auto generated imports
import tagion.behaviour.BehaviourException;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourResult;

enum feature = Feature(
            "Some awesome feature should print some cash out of the blue",
            []);
alias FeatureContext = Tuple!(
        Some_awesome_feature, "Some_awesome_feature",
        Some_awesome_feature_bad_format_double_property, "Some_awesome_feature_bad_format_double_property",
        Some_awesome_feature_bad_format_missing_given, "Some_awesome_feature_bad_format_missing_given",
        Some_awesome_feature_bad_format_missing_then, "Some_awesome_feature_bad_format_missing_then",
        FeatureGroup*, "result"
);
@safe @Scenario("Some awesome money printer",
        [])
class Some_awesome_feature {
    @Given("the card is valid")
    Document is_valid() {
        return Document();
    }

    @Given("the account is in credit")
    Document in_credit() {
        return Document();
    }

    @Given("the dispenser contains cash")
    Document contains_cash() {
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

    @But("if the Customer does not take his card, then the card must be swollowed")
    Document swollow_the_card() {
        return Document();
    }
}

@safe @Scenario("Some money printer which is controlled by a bankster",
        [])
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

@safe @Scenario("Some money printer which has run out of paper",
        [])
class Some_awesome_feature_bad_format_missing_given {
    @Then("the account is debited ")
    Document is_debited_bad_one() {
        return Document();
    }

    @Then("the cash is dispensed")
    Document is_dispensed() {
        return Document();
    }
}

@safe @Scenario("Some money printer which is gone wild and prints toilet paper",
        [])
class Some_awesome_feature_bad_format_missing_then {
    @Given("the card is valid")
    Document is_valid() {
        return Document();
    }
}
