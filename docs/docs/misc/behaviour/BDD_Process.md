## BDD Process

**Behavior Driven Development** 

Is a process that encourages collaboration among developers, quality assurance testers, and customer representatives in a software project.

It encourages the teams to use conversation and concrete examples to formalize a shared understanding of how the application should behave including a **exit criteria**.

BDD uses a description in a simplified  English which can be converted to skeleton written in the programming language used for development. 

There are several different types of BDD language, but for our purpose we will use a very simple type. Which includes few keywords ***Feature, Scenario, Given, When, Then, But***

A BDD include a title marked with the keyword ***Feature***

A feature must have one or more Scenario's indicated with the keyword ***Scenario***.

A Scenario must include one or more ***Given*** which describes the conditions which must be in-place as start condition for the Scenario.

A Scenario can include one or more ***When*** statement, which describes the action performed on the system.

Finally a Scenario must include one or more ***Then*** statement which describes what is expected to happen. This is the ***exit criteria*** for the Scenario.

A Scenario can also include one or more ***But***, this is use to check for conditions which should ***not*** occur at the end of the Scenario.

 

 

Example of a BDD in markdown format.

## Feature: Some awesome feature should print some cash out of the blue

`tagion.behaviour.BehaviourUnittest`
### Scenario: Some awesome money printer

`Some_awesome_feature`
    *Given* the card is valid

`is_valid`
      *Given* the account is in credit

`in_credit`
      *Given* the dispenser contains cash

`contains_cash`
    *When* the Customer request cash

`request_cash`
    *Then* the account is debited

`is_debited`
      *Then* the cash is dispensed

`is_dispensed`

### Scenario: Some money printer which is controlled by a bankster

`Some_awesome_feature_bad_format_double_property`
    *Given* the card is valid

`is_valid`
    *When* the Customer request cash

`request_cash`
    *Then* the account is debited

`is_debited`
      *Then* the cash is dispensed

`is_dispensed`



From the BDD in markdown form the skeleton D-code is produces.



Produces this code:

```d
module tagion.behaviour.BehaviourUnittest;

// Auto generated imports
import tagion.behaviour.BehaviourBase;
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

}

@safe @Scenario("Some money printer which is controlled by a bankster",
        [])
class Some_awesome_feature_bad_format_double_property {

    @Given("the card is valid")
    Document is_valid() {
        check(false, "Check for 'is_valid' not implemented");
        return Document();
    }

    @Given("the Customer request cash")
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

```



A BDD should be executed in order from the first ***Scenario*** to the last and a ***Scenario*** executed this in the order of ***Given*** -> ***When*** -> ***Then*** -> ***But***. this is called actions. An action can produces an output if an Scenario fails in the sequence of actions it should stop and continue to the next Scenario in the BDD.

The out of the BDD (Feature) should be stored in a file an can be process or analyzed after the test has been performed.

```d
/// Example executing the Scenario Some_awesome_feature.
const scenario_result = run!(Some_awesome_feature); 

/// Example executing the full BDD tagion.behaviour.BehaviourUnittest
const feature_result = run!(tagion.behaviour.BehaviourUnittest);
    
```



The tools should produces and **D** source-file from a **markdown** file and it should be able to produce a **markdown** from a BDD **D** source file. Which enables both forward and backward annotation of information.

