module tagion.behaviour.BehaviourUnittest;
// Auto generated imports
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourException;
enum feature = Feature(
"Some awesome feature should print some cash out of the blue",
[]);
@safe @Scenario("Some awesome money printer",
[])
class Some_awesome_feature {
@Given("the card is valid")
Document is_valid() {
check(false, "Check for 'is_valid' not implemented");
return Document();
}
@Given("the account is in credit")
Document in_credit() {
check(false, "Check for 'in_credit' not implemented");
return Document();
}
@Given("the dispenser contains cash")
Document contains_cash() {
check(false, "Check for 'contains_cash' not implemented");
return Document();
}
@When("the Customer request cash")
Document request_cash() {
check(false, "Check for 'request_cash' not implemented");
return Document();
}
@Then("the account is debited")
Document is_debited() {
check(false, "Check for 'is_debited' not implemented");
return Document();
}
@Then("the cash is dispensed")
Document is_dispensed() {
check(false, "Check for 'is_dispensed' not implemented");
return Document();
}
@But("if the Customer does not take his card, then the card must be swollowed")
Document swollow_the_card() {
check(false, "Check for 'swollow_the_card' not implemented");
return Document();
}
}
@safe @Scenario("Some money printer which is controlled by a bankster",
[])
class Some_awesome_feature_bad_format_double_property {
@Given("the card is valid")
Document is_valid() {
check(false, "Check for 'is_valid' not implemented");
return Document();
}
@When("the Customer request cash")
Document request_cash() {
check(false, "Check for 'request_cash' not implemented");
return Document();
}
@Then("the account is debited")
Document is_debited() {
check(false, "Check for 'is_debited' not implemented");
return Document();
}
@Then("the cash is dispensed")
Document is_dispensed() {
check(false, "Check for 'is_dispensed' not implemented");
return Document();
}
}
@safe @Scenario("Some money printer which has run out of paper",
[])
class Some_awesome_feature_bad_format_missing_given {
@Then("the account is debited ")
Document is_debited_bad_one() {
check(false, "Check for 'is_debited_bad_one' not implemented");
return Document();
}
@Then("the cash is dispensed")
Document is_dispensed() {
check(false, "Check for 'is_dispensed' not implemented");
return Document();
}
}
@safe @Scenario("Some money printer which is gone wild and prints toilet paper",
[])
class Some_awesome_feature_bad_format_missing_then {
@Given("the card is valid")
Document is_valid() {
check(false, "Check for 'is_valid' not implemented");
return Document();
}
}