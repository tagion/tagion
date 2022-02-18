module tagion.behavior.Behavior;

struct Feature {
    string description;
}

struct Given {
    string description;
}

struct And {
    string description;
}

struct When {
    string description;
}

struct Then {
    string description;
}

unittest {
    @Feature("Some awesome feature should print some cash out of the blue")
        class Some_awesome_feature {
            @Given("that the card is valid")
            bool is_valid() {
                return false;
            }
            @And("the account is in credit")
            bool in_creatit() {
                return false;
            }
            @And("the dispenser contains cash")
            bool contains_cash() {
                return false;
            }
            @When("the Constumer request cash")
            bool request_cash() {
                return false;
            }
            @Then("the account is debited")
            bool is_debited() {
                return false;
            }
            @And("the cash is dispensed")
            bool is_dispensed() {
                return false;
            }
        }

}
